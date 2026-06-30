import 'package:flutter/material.dart';

import '../playback_controller.dart';

/// 비디오 렌더링 영역. 실제 위젯은 엔진(media_kit/video_player)이 만든다.
class VideoView extends StatelessWidget {
  const VideoView({super.key, required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    return controller.buildVideoView();
  }
}
