import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'player_screen.dart';

Future<void> main() async {
  // 플러그인 채널 사용 전 바인딩 보장
  WidgetsFlutterBinding.ensureInitialized();

  // 재생 백엔드 초기화: Windows는 media_kit, Android는 네이티브 video_player(ExoPlayer)
  VideoPlayerMediaKit.ensureInitialized(
    windows: true, // Windows → media_kit(mpv) 백엔드
    android: false, // Android → 네이티브 ExoPlayer 유지
  );

  // Windows: 창 제어(풀스크린/해상도) 초기화
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(960, 640),
        center: true,
        title: '비디오 재생 성능 테스트 랩',
      ),
      () async => windowManager.show(),
    );
  }

  runApp(const VideoPerfApp());
}

/// 앱 루트
class VideoPerfApp extends StatelessWidget {
  const VideoPerfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '비디오 재생 성능 테스트 랩',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const PlayerScreen(),
    );
  }
}
