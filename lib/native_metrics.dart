import 'dart:io';

import 'package:flutter/services.dart';

/// CPU%/GPU%/GPU 이름을 가져온다.
/// - Windows: 네이티브 채널 'video_perf/metrics'(C++)
/// - Android: /proc/self/stat 기반 CPU%(순수 Dart), GPU%는 미수집
class NativeMetrics {
  static const _channel = MethodChannel('video_perf/metrics');

  // Android CPU% 계산용 직전 샘플
  static int? _prevTicks;
  static DateTime? _prevTime;
  static final int _cores = Platform.numberOfProcessors;

  /// CPU%/GPU% 샘플. 미지원/실패 시 null 또는 일부 필드 null.
  static Future<({double? cpu, double? gpu})?> sample() async {
    if (Platform.isWindows) {
      try {
        final m = await _channel.invokeMapMethod<String, dynamic>('sample');
        if (m == null) return null;
        return (
          cpu: (m['cpu'] as num?)?.toDouble(),
          gpu: (m['gpu'] as num?)?.toDouble(),
        );
      } catch (_) {
        return null;
      }
    }
    if (Platform.isAndroid) {
      // Android는 CPU%만(순수 Dart), GPU%는 벤더 비공개라 null
      return (cpu: await _androidCpu(), gpu: null);
    }
    return null;
  }

  /// 설치된 GPU(어댑터) 목록. Windows만 지원, 그 외 빈 목록.
  static Future<List<String>> gpuList() async {
    if (!Platform.isWindows) return const [];
    try {
      final l = await _channel.invokeListMethod<String>('gpuList');
      return l ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// 기본 GPU 어댑터 이름. Windows만 지원, 그 외 null.
  static Future<String?> gpuName() async {
    if (!Platform.isWindows) return null;
    try {
      final s = await _channel.invokeMethod<String>('gpuName');
      return (s == null || s.isEmpty) ? null : s;
    } catch (_) {
      return null;
    }
  }

  // /proc/self/stat 의 utime+stime(클럭틱) 델타로 프로세스 CPU% 계산
  static Future<double?> _androidCpu() async {
    try {
      final stat = await File('/proc/self/stat').readAsString();
      // comm 필드에 공백/괄호가 있을 수 있어 마지막 ')' 이후부터 파싱
      final close = stat.lastIndexOf(')');
      final rest = stat.substring(close + 2).trim().split(RegExp(r'\s+'));
      // rest[0]=state(3번 필드) → utime=14번(rest[11]), stime=15번(rest[12])
      final ticks = int.parse(rest[11]) + int.parse(rest[12]);
      final now = DateTime.now();
      if (_prevTicks == null || _prevTime == null) {
        _prevTicks = ticks;
        _prevTime = now;
        return 0;
      }
      final dTicks = ticks - _prevTicks!;
      final dSec = now.difference(_prevTime!).inMilliseconds / 1000.0;
      _prevTicks = ticks;
      _prevTime = now;
      if (dSec <= 0) return 0;
      const hz = 100; // USER_HZ (Android은 일반적으로 100)
      var pct = (dTicks / hz) / (dSec * _cores) * 100.0;
      if (pct < 0) pct = 0;
      if (pct > 100) pct = 100;
      return pct;
    } catch (_) {
      return null;
    }
  }
}
