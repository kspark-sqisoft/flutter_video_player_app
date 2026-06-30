import 'package:flutter/material.dart';

import '../models.dart';
import '../playback_controller.dart';

/// 비디오 위에 오버레이되는 디버그 HUD (사양·실시간 지표·영상 정보·엔진 비교)
class DebugHud extends StatelessWidget {
  const DebugHud({super.key, required this.controller, required this.specs});

  final PlaybackController controller;
  final SystemSpecs specs;

  @override
  Widget build(BuildContext context) {
    final m = controller.metrics;
    final info = controller.videoInfo;
    // IgnorePointer: HUD가 비디오 클릭/제스처를 가로채지 않도록
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.4,
            fontFamily: 'monospace',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _section('PC 사양'),
              _row('CPU', '${specs.cpuModel} (${specs.cpuCores} 코어)'),
              _row('RAM', _mb(specs.totalRamBytes)),
              _row('GPU', specs.gpuName),
              const SizedBox(height: 6),
              _section('실시간 지표'),
              _row('화면 FPS', m.screenFps.toStringAsFixed(1)),
              _row('디코드 FPS', _fps(m.decodeFps)),
              _row('컨테이너 FPS', _fps(m.containerFps)),
              _row('드롭(출력/디코더)',
                  '${m.frameDrops ?? '-'} / ${m.decoderDrops ?? '-'}'),
              _row('비디오 비트레이트', _mbps(m.videoBitrate)),
              _row('오디오 비트레이트', _kbps(m.audioBitrate)),
              _row('메모리(RSS)', _mb(m.memoryBytes)),
              _row('CPU 사용률', _pct(m.cpuUsage)),
              _row('GPU 사용률', _pct(m.gpuUsage)),
              const SizedBox(height: 6),
              _section('영상 정보'),
              _row('코덱', info.codec ?? '-'),
              _row('컨테이너', info.container ?? '-'),
              _row('해상도', info.resolution),
              _row('오디오', info.audioCodec ?? '-'),
              _row('hwdec', info.hwdec ?? '-'),
              _row('픽셀포맷', info.pixelFormat ?? '-'),
              const SizedBox(height: 6),
              _section('media_kit(mpv) vs Windows Media Player'),
              _note('• 코덱: FFmpeg 내장 디코더라 OS 코덱 설치와 무관하게 재생. '
                  'WMP는 OS(Media Foundation)+설치된 코덱에 의존 → 기기마다 지원 상이.'),
              _note('• 디코딩: hwdec로 SW(CPU)↔HW(d3d11va/nvdec) 수동 전환·계측 가능. '
                  'WMP는 DXVA를 자동 사용하며 사용자 제어가 거의 없음.'),
              _note('• 일관성: 자체 번들로 크로스플랫폼 동일 동작. WMP는 Windows 종속.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );

  Widget _row(String k, String v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(child: Text(v)),
        ],
      );

  // 비교 설명 한 줄 (작은 글씨)
  Widget _note(String t) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(t, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      );

  String _mb(int bytes) =>
      bytes <= 0 ? '-' : '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  String _fps(double? v) => v == null ? '-' : v.toStringAsFixed(1);
  String _pct(double? v) => v == null ? '-' : '${v.toStringAsFixed(1)} %';
  String _mbps(double? bps) =>
      bps == null ? '-' : '${(bps / 1e6).toStringAsFixed(2)} Mbps';
  String _kbps(double? bps) =>
      bps == null ? '-' : '${(bps / 1e3).toStringAsFixed(0)} kbps';
}
