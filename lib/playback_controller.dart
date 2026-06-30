import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'exo_playback_controller.dart';
import 'models.dart';
import 'native_metrics.dart';

// mpv 전용(엔진별) 지표 묶음
typedef MpvExtras = ({
  double? decodeFps,
  double? containerFps,
  int? frameDrops,
  int? decoderDrops,
  double? videoBitrate,
  double? audioBitrate,
});

/// 플랫폼별 재생 엔진을 생성하는 팩토리.
PlaybackController createPlaybackController() =>
    Platform.isAndroid ? ExoPlaybackController() : MediaKitPlaybackController();

/// 재생 엔진 공통 추상화. 화면은 이 ChangeNotifier를 듣고 갱신한다.
abstract class PlaybackController extends ChangeNotifier {
  // 공통 상태
  String? filePath;
  bool isReady = false;
  bool isPlaying = false;
  bool isBuffering = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  Duration buffer = Duration.zero;
  bool isCompleted = false;

  // 설정
  PlaybackEndMode endMode = PlaybackEndMode.loop;
  BoxFit boxFit = BoxFit.contain;
  bool hudVisible = true;

  // 지표
  PlaybackMetrics metrics = PlaybackMetrics.empty;
  VideoInfo videoInfo = VideoInfo.empty;

  // once 모드 메모리 해제 관찰
  int? memBeforeDisposeBytes;
  int? memAfterDisposeBytes;

  // 화면 FPS 계산 인프라
  int _frameCount = 0;
  DateTime _fpsWindowStart = DateTime.now();
  late final TimingsCallback _timingsCallback;
  Timer? _metricsTimer;

  // notifyListeners 스로틀(고빈도 갱신 합치기 → 리빌드/접근성 트리 부담 감소)
  Timer? _throttleTimer;
  bool _pendingNotify = false;

  // hwdec 미지원 엔진용 더미 옵션
  final MpvOption _dummyHwdec = MpvOption(
    name: 'hwdec',
    label: 'hwdec',
    choices: const ['no', 'auto', 'auto-safe'],
  );

  PlaybackController() {
    // Flutter 렌더 프레임 수를 세어 화면 FPS를 계산
    _timingsCallback = (timings) => _frameCount += timings.length;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
  }

  // --- 엔진 정보(서브클래스가 필요 시 override) ---
  String get engineLabel; // 예: 'media_kit (mpv)'
  bool get supportsMpvOptions => false; // 옵션 패널/hwdec 지원 여부
  bool get nativeAvailable => false; // mpv 심층 지표 가용
  List<MpvOption> get mpvOptions => const [];
  MpvOption get hwdecOption => _dummyHwdec;
  Future<void> applyOption(MpvOption opt, String value) async {}
  Future<void> setHwdec(String value) => applyOption(hwdecOption, value);
  Future<void> resetAllOptions() async {} // 모든 옵션을 기본값으로 복원
  Future<MpvExtras?> readMpvExtras() async => null; // 기본: mpv 지표 없음

  // 설치된 GPU 목록(정보 표시용).
  // 인앱 GPU 전환은 렌더 D3D11 디바이스가 제거되어 불안정 → 미지원(Windows 그래픽 설정으로 안내).
  List<String> availableGpus = const [];

  // --- 엔진별 동작(필수 구현) ---
  Widget buildVideoView();
  Future<void> openFile(String path);
  Future<void> togglePlayPause();
  Future<void> seek(Duration to);
  Future<void> setEndMode(PlaybackEndMode mode);

  // --- 공통 동작 ---
  void setBoxFit(BoxFit fit) {
    boxFit = fit;
    notifyListeners();
  }

  void toggleHud() {
    hudVisible = !hudVisible;
    notifyListeners();
  }

  // 공통 지표 타이머 (화면 FPS + 메모리 + CPU/GPU + 엔진별 mpv 지표)
  @protected
  void startMetricsTimer() {
    _metricsTimer?.cancel();
    _fpsWindowStart = DateTime.now();
    _frameCount = 0;
    _metricsTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollMetrics(),
    );
  }

  @protected
  void stopMetricsTimer() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }

  // 고빈도 알림을 ~11Hz로 합쳐 리빌드/접근성 트리 부담을 줄인다.
  @protected
  void notifyThrottled() {
    if (_throttleTimer != null) {
      _pendingNotify = true;
      return;
    }
    notifyListeners();
    _throttleTimer = Timer(const Duration(milliseconds: 90), () {
      _throttleTimer = null;
      if (_pendingNotify) {
        _pendingNotify = false;
        notifyThrottled();
      }
    });
  }

  Future<void> _pollMetrics() async {
    final now = DateTime.now();
    final elapsed = now.difference(_fpsWindowStart).inMilliseconds / 1000.0;
    final screenFps = elapsed > 0 ? _frameCount / elapsed : 0.0;
    _frameCount = 0;
    _fpsWindowStart = now;

    final memBytes = ProcessInfo.currentRss; // 메모리(RSS)
    final sys = await NativeMetrics.sample(); // CPU%/GPU%
    final mpv = await readMpvExtras(); // 엔진별 mpv 지표

    metrics = PlaybackMetrics(
      decodeFps: mpv?.decodeFps,
      containerFps: mpv?.containerFps,
      frameDrops: mpv?.frameDrops,
      decoderDrops: mpv?.decoderDrops,
      videoBitrate: mpv?.videoBitrate,
      audioBitrate: mpv?.audioBitrate,
      screenFps: screenFps,
      memoryBytes: memBytes,
      cpuUsage: sys?.cpu,
      gpuUsage: sys?.gpu,
    );
    notifyThrottled();
  }

  // once 모드: 해제 전/후 메모리 기록 헬퍼
  @protected
  void recordMemBefore() => memBeforeDisposeBytes = ProcessInfo.currentRss;

  @protected
  Future<void> recordMemAfter() async {
    await Future.delayed(const Duration(milliseconds: 500));
    memAfterDisposeBytes = ProcessInfo.currentRss;
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    stopMetricsTimer();
    _throttleTimer?.cancel();
    super.dispose();
  }
}

/// Windows 경로: media_kit(mpv) Player 직접 사용.
class MediaKitPlaybackController extends PlaybackController {
  Player? _player;
  VideoController? _videoController;

  final List<MpvOption> _mpvOptions = defaultMpvOptions();
  final List<StreamSubscription> _subs = [];

  MediaKitPlaybackController() {
    _loadGpuList(); // 설치된 GPU 목록 미리 조회
  }

  @override
  String get engineLabel => 'media_kit (mpv/FFmpeg)';
  @override
  bool get supportsMpvOptions => true;
  @override
  bool get nativeAvailable => _player?.platform is NativePlayer;
  @override
  List<MpvOption> get mpvOptions => _mpvOptions;
  @override
  MpvOption get hwdecOption => _mpvOptions.firstWhere((o) => o.name == 'hwdec');

  Future<void> _loadGpuList() async {
    availableGpus = await NativeMetrics.gpuList();
    notifyListeners();
  }

  @override
  Widget buildVideoView() {
    final vc = _videoController;
    if (vc == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('비디오 파일을 선택하세요',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }
    return Video(
      controller: vc,
      fit: boxFit,
      fill: Colors.black,
      controls: NoVideoControls,
    );
  }

  @override
  Future<void> openFile(String path) async {
    await _disposePlayerInternal(recordMemory: false);
    isCompleted = false;
    memBeforeDisposeBytes = null;
    memAfterDisposeBytes = null;
    filePath = path;
    videoInfo = VideoInfo.empty;
    _resetOptions();

    final player = Player();
    final videoController = VideoController(player);
    _player = player;
    _videoController = videoController;

    _bindStreams(player);
    await player.setPlaylistMode(
      endMode == PlaybackEndMode.loop ? PlaylistMode.single : PlaylistMode.none,
    );

    isReady = true;
    notifyListeners();

    await player.open(Media(path), play: true);

    startMetricsTimer();
    // 정적 영상 정보·옵션 기본값은 잠시 후 1회 읽기
    Future.delayed(const Duration(milliseconds: 800), () {
      _readVideoInfo();
      _loadOptionDefaults();
    });
  }

  @override
  Future<void> togglePlayPause() async => _player?.playOrPause();

  @override
  Future<void> seek(Duration to) async => _player?.seek(to);

  @override
  Future<void> setEndMode(PlaybackEndMode mode) async {
    endMode = mode;
    await _player?.setPlaylistMode(
      mode == PlaybackEndMode.loop ? PlaylistMode.single : PlaylistMode.none,
    );
    notifyListeners();
  }

  @override
  Future<MpvExtras?> readMpvExtras() async {
    final native = _player?.platform;
    if (native is! NativePlayer) return null;
    final r = await Future.wait([
      native.getProperty('estimated-vf-fps'),
      native.getProperty('container-fps'),
      native.getProperty('frame-drop-count'),
      native.getProperty('decoder-frame-drop-count'),
      native.getProperty('video-bitrate'),
      native.getProperty('audio-bitrate'),
    ]);
    return (
      decodeFps: double.tryParse(r[0]),
      containerFps: double.tryParse(r[1]),
      frameDrops: int.tryParse(r[2]),
      decoderDrops: int.tryParse(r[3]),
      videoBitrate: double.tryParse(r[4]),
      audioBitrate: double.tryParse(r[5]),
    );
  }

  @override
  Future<void> applyOption(MpvOption opt, String value) async {
    final native = _player?.platform;
    if (native is! NativePlayer) return;
    opt.requestedValue = value;
    await native.setProperty(opt.name, value);
    final eff = await native.getProperty(opt.name);
    opt.effectiveValue = _orNull(eff);
    if (opt.name == 'hwdec') {
      final cur = await native.getProperty('hwdec-current');
      videoInfo = VideoInfo(
        codec: videoInfo.codec,
        container: videoInfo.container,
        width: videoInfo.width,
        height: videoInfo.height,
        audioCodec: videoInfo.audioCodec,
        hwdec: _orNull(cur),
        pixelFormat: videoInfo.pixelFormat,
      );
    }
    notifyListeners();
  }

  @override
  Future<void> resetAllOptions() async {
    final native = _player?.platform;
    if (native is! NativePlayer) return;
    // 각 옵션을 기본값(읽은 값 우선, 없으면 하드코딩)으로 되돌린다
    for (final o in _mpvOptions) {
      final base = o.baseValue;
      if (base == null) continue;
      await native.setProperty(o.name, base);
      o.requestedValue = null;
      o.effectiveValue = base;
    }
    // hwdec 복원 반영(현재 디코더 갱신)
    final cur = await native.getProperty('hwdec-current');
    videoInfo = VideoInfo(
      codec: videoInfo.codec,
      container: videoInfo.container,
      width: videoInfo.width,
      height: videoInfo.height,
      audioCodec: videoInfo.audioCodec,
      hwdec: _orNull(cur),
      pixelFormat: videoInfo.pixelFormat,
    );
    notifyListeners();
  }

  // --- 내부 ---

  void _bindStreams(Player player) {
    final s = player.stream;
    _subs.addAll([
      s.playing.listen((v) {
        isPlaying = v;
        notifyListeners();
      }),
      s.buffering.listen((v) {
        isBuffering = v;
        notifyListeners();
      }),
      s.position.listen((v) {
        position = v;
        notifyThrottled();
      }),
      s.duration.listen((v) {
        duration = v;
        notifyListeners();
      }),
      s.buffer.listen((v) {
        buffer = v;
        notifyThrottled();
      }),
      s.completed.listen(_onCompleted),
      s.width.listen((_) => _readVideoInfo()),
    ]);
  }

  Future<void> _onCompleted(bool completed) async {
    if (!completed) return;
    if (endMode == PlaybackEndMode.once) {
      isCompleted = true;
      await _disposePlayerInternal(recordMemory: true);
      notifyListeners();
    }
  }

  Future<void> _readVideoInfo() async {
    final native = _player?.platform;
    if (native is! NativePlayer) return;
    final r = await Future.wait([
      native.getProperty('video-codec'),
      native.getProperty('file-format'),
      native.getProperty('audio-codec'),
      native.getProperty('hwdec-current'),
      native.getProperty('video-params/pixelformat'),
    ]);
    videoInfo = VideoInfo(
      codec: _orNull(r[0]),
      container: _orNull(r[1]),
      audioCodec: _orNull(r[2]),
      hwdec: _orNull(r[3]),
      pixelFormat: _orNull(r[4]),
      width: _player?.state.width,
      height: _player?.state.height,
    );
    notifyListeners();
  }

  void _resetOptions() {
    for (final o in _mpvOptions) {
      o.defaultValue = null;
      o.requestedValue = null;
      o.effectiveValue = null;
    }
  }

  Future<void> _loadOptionDefaults() async {
    final native = _player?.platform;
    if (native is! NativePlayer) return;
    for (final o in _mpvOptions) {
      final v = await native.getProperty(o.name);
      o.defaultValue = _orNull(v);
      o.effectiveValue = _orNull(v);
    }
    notifyListeners();
  }

  String? _orNull(String v) => v.isEmpty ? null : v;

  Future<void> _disposePlayerInternal({required bool recordMemory}) async {
    stopMetricsTimer();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();

    final p = _player;
    if (p == null) {
      _videoController = null;
      isReady = false;
      return;
    }

    if (recordMemory) recordMemBefore();

    await p.dispose();
    _player = null;
    _videoController = null;
    isReady = false;

    if (recordMemory) await recordMemAfter();
  }

  @override
  void dispose() {
    _disposePlayerInternal(recordMemory: false);
    super.dispose();
  }
}
