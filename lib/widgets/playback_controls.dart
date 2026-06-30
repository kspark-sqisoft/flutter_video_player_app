import 'package:flutter/material.dart';

import '../playback_controller.dart';

/// 재생 컨트롤 바: 재생/일시정지, 시크 프로그레스(버퍼 구간 표시), 버퍼링 표시
class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key, required this.controller});

  final PlaybackController controller;

  // Duration → mm:ss (또는 h:mm:ss)
  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final durMs = c.duration.inMilliseconds.toDouble();
    final posMs = c.position.inMilliseconds
        .toDouble()
        .clamp(0.0, durMs <= 0 ? 0.0 : durMs);
    // 버퍼링 구간 비율
    final bufFrac =
        durMs > 0 ? (c.buffer.inMilliseconds / durMs).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // 재생/일시정지
          IconButton(
            icon: Icon(c.isPlaying ? Icons.pause : Icons.play_arrow),
            color: Colors.white,
            onPressed: c.isReady ? c.togglePlayPause : null,
          ),
          // 현재 시간
          Text(_fmt(c.position),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          // 시크 바 (버퍼 구간을 슬라이더 뒤에 옅게 표시)
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LinearProgressIndicator(
                    value: bufFrac,
                    minHeight: 3,
                    backgroundColor: Colors.white12,
                    color: Colors.white30,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: durMs > 0 ? posMs : 0,
                    max: durMs > 0 ? durMs : 1,
                    onChanged: c.isReady && durMs > 0
                        ? (v) => c.seek(Duration(milliseconds: v.round()))
                        : null,
                  ),
                ),
              ],
            ),
          ),
          // 총 길이
          Text(_fmt(c.duration),
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8),
          // 버퍼링 인디케이터
          SizedBox(
            width: 20,
            height: 20,
            child: c.isBuffering
                ? const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)
                : null,
          ),
        ],
      ),
    );
  }
}
