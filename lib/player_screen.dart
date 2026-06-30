import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'models.dart';
import 'playback_controller.dart';
import 'system_info_service.dart';
import 'widgets/debug_hud.dart';
import 'widgets/playback_controls.dart';
import 'widgets/settings_panel.dart';
import 'widgets/video_view.dart';

/// 메인 화면: 좌측(비디오 + HUD + 컨트롤) + 우측(설정 패널)
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // 플랫폼에 맞는 재생 엔진 생성 (Windows=media_kit, Android=video_player)
  final PlaybackController _controller = createPlaybackController();
  SystemSpecs _specs = SystemSpecs.empty;
  bool _isFullScreen = false;
  bool _settingsVisible = true; // 설정 패널 표시 여부(기본 열림)

  @override
  void initState() {
    super.initState();
    // 하드웨어 사양 1회 조회
    loadSystemSpecs().then((s) {
      if (mounted) setState(() => _specs = s);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 전체화면: 타이틀바 숨김 + 최대화 사용.
  // (windowManager.setFullScreen은 일부 환경에서 창이 사라지는 문제가 있어 쓰지 않음)
  Future<void> _toggleFullScreen() async {
    if (!Platform.isWindows) return;
    final next = !_isFullScreen;
    if (next) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
          windowButtonVisibility: false);
      await windowManager.maximize();
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.unmaximize();
    }
    if (mounted) {
      setState(() {
        _isFullScreen = next;
        // 전체화면 진입 시 설정 패널 자동 숨김, 해제 시 다시 표시 (F1로 재토글 가능)
        _settingsVisible = !next;
      });
    }
  }

  // 키 처리: ESC=전체화면 해제, F1=설정 패널 토글(전체화면에서도 동작)
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _isFullScreen) {
      _toggleFullScreen();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f1) {
      setState(() => _settingsVisible = !_settingsVisible);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // 앱 화면 전체를 semantics에서 제외 → Windows 접근성 트리 갱신 에러(스팸) 차단.
    // (클릭/키 입력은 정상 동작, 스크린리더 노출만 빠짐 — 개발/테스트 도구라 허용)
    return ExcludeSemantics(
      child: Scaffold(
        // 전체화면이면 AppBar(타이틀바처럼 보임)도 숨겨 몰입형으로
        appBar: _isFullScreen
            ? null
            : AppBar(
                title: const Text('비디오 재생 성능 테스트 랩'),
                actions: [
                  IconButton(
                    tooltip: '설정 패널 토글 (F1)',
                    icon: Icon(_settingsVisible
                        ? Icons.view_sidebar
                        : Icons.view_sidebar_outlined),
                    onPressed: () =>
                        setState(() => _settingsVisible = !_settingsVisible),
                  ),
                  if (Platform.isWindows)
                    IconButton(
                      tooltip: '전체화면 (ESC로 해제)',
                      icon: const Icon(Icons.fullscreen),
                      onPressed: _toggleFullScreen,
                    ),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => IconButton(
                      tooltip: 'HUD 토글',
                      icon: Icon(_controller.hudVisible
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: _controller.toggleHud,
                    ),
                  ),
                ],
              ),
        body: Focus(
          autofocus: true,
          onKeyEvent: _handleKey,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Row(
                children: [
                  // 좌측: 비디오 영역 + 컨트롤
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: VideoView(controller: _controller),
                              ),
                              // 오버레이 HUD (토글 시 표시)
                              if (_controller.hudVisible)
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: DebugHud(
                                      controller: _controller, specs: _specs),
                                ),
                            ],
                          ),
                        ),
                        PlaybackControls(controller: _controller),
                      ],
                    ),
                  ),
                  // 우측: 설정 패널 (토글 가능, 기본 열림 / 전체화면 진입 시 자동 숨김)
                  if (_settingsVisible) SettingsPanel(controller: _controller),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
