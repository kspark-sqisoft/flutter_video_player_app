import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'models.dart';
import 'playback_controller.dart';

/// Android 경로: 네이티브 video_player(ExoPlayer) 사용.
/// mpv 전용 지표/옵션은 미지원(기본 지표만 제공).
class ExoPlaybackController extends PlaybackController {
  VideoPlayerController? _vp;

  @override
  String get engineLabel => 'video_player (ExoPlayer)';

  @override
  Widget buildVideoView() {
    final vp = _vp;
    if (vp == null || !vp.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('비디오 파일을 선택하세요',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }
    final size = vp.value.size;
    // video_player 위젯은 BoxFit 미지원 → FittedBox로 맞춤 적용
    return ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: Center(
          child: FittedBox(
            fit: boxFit,
            child: SizedBox(
              width: size.width <= 0 ? 16 : size.width,
              height: size.height <= 0 ? 9 : size.height,
              child: VideoPlayer(vp),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Future<void> openFile(String path) async {
    await _disposeVp(recordMemory: false);
    isCompleted = false;
    memBeforeDisposeBytes = null;
    memAfterDisposeBytes = null;
    filePath = path;
    videoInfo = VideoInfo.empty;

    final vp = VideoPlayerController.file(File(path));
    _vp = vp;
    vp.addListener(_onVpUpdate);
    await vp.initialize();
    await vp.setLooping(endMode == PlaybackEndMode.loop);
    await vp.play();

    isReady = true;
    // video_player가 제공하는 기본 정보(해상도). 코덱/hwdec은 미수집.
    videoInfo = VideoInfo(
      width: vp.value.size.width.toInt(),
      height: vp.value.size.height.toInt(),
    );
    duration = vp.value.duration;
    startMetricsTimer();
    notifyListeners();
  }

  @override
  Future<void> togglePlayPause() async {
    final vp = _vp;
    if (vp == null) return;
    if (vp.value.isPlaying) {
      await vp.pause();
    } else {
      await vp.play();
    }
  }

  @override
  Future<void> seek(Duration to) async => _vp?.seekTo(to);

  @override
  Future<void> setEndMode(PlaybackEndMode mode) async {
    endMode = mode;
    await _vp?.setLooping(mode == PlaybackEndMode.loop);
    notifyListeners();
  }

  // video_player 값 변경 → 공통 상태로 반영
  void _onVpUpdate() {
    final vp = _vp;
    if (vp == null) return;
    final v = vp.value;
    isPlaying = v.isPlaying;
    isBuffering = v.isBuffering;
    position = v.position;
    duration = v.duration;
    buffer = v.buffered.isNotEmpty ? v.buffered.last.end : Duration.zero;
    // once 모드 종료 처리 (리스너 콜백 밖에서 해제)
    if (v.isCompleted && endMode == PlaybackEndMode.once && !isCompleted) {
      isCompleted = true;
      Future.microtask(
          () => _disposeVp(recordMemory: true).then((_) => notifyListeners()));
    }
    notifyThrottled();
  }

  Future<void> _disposeVp({required bool recordMemory}) async {
    stopMetricsTimer();
    final vp = _vp;
    if (vp == null) {
      isReady = false;
      return;
    }
    vp.removeListener(_onVpUpdate);
    if (recordMemory) recordMemBefore();
    await vp.dispose();
    _vp = null;
    isReady = false;
    if (recordMemory) await recordMemAfter();
  }

  @override
  void dispose() {
    _disposeVp(recordMemory: false);
    super.dispose();
  }
}
