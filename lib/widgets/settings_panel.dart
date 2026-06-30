import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../playback_controller.dart';
import 'mpv_options_section.dart';
import 'window_controls_section.dart';

/// 우측 설정 패널: 파일·BoxFit·종료정책·HUD·디코딩(hwdec)·창 제어·mpv 옵션
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.controller});

  final PlaybackController controller;

  Future<void> _pickFile() async {
    // 네이티브 탐색기로 비디오 파일 1개 선택
    const group = XTypeGroup(
      label: '비디오',
      extensions: [
        'mp4', 'mkv', 'webm', 'mov', 'avi',
        'ts', 'm4v', 'flv', 'wmv', 'm2ts',
      ],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file != null) {
      await controller.openFile(file.path);
    }
  }

  // Windows 앱별 그래픽(GPU) 설정 페이지 열기
  Future<void> _openGraphicsSettings() async {
    try {
      await Process.run(
          'explorer.exe', ['ms-settings:display-advancedgraphics']);
    } catch (_) {}
  }

  // hwdec 빠른 토글의 현재 선택값 계산 (CPU/GPU/자동)
  String _hwdecSelected(PlaybackController c) {
    final v = c.hwdecOption.requestedValue ?? c.hwdecOption.effectiveValue;
    if (v == 'no') return 'no';
    if (v == 'auto') return 'auto';
    return 'auto-safe'; // 그 외(auto-safe/d3d11va 등)는 GPU로 표시
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // Material로 감싸 ListTile 잉크가 가려지는 문제 방지(+배경색)
    return Material(
      color: const Color(0xFF1E1E1E),
      child: SizedBox(
        width: 360,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // 파일 선택
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('비디오 파일 선택'),
            ),
            const SizedBox(height: 8),
            Text(
              c.filePath ?? '(선택된 파일 없음)',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Divider(height: 24),
            // 화면 맞춤 (BoxFit)
            const Text('화면 맞춤 (BoxFit)'),
            DropdownButton<BoxFit>(
              value: c.boxFit,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                    value: BoxFit.contain, child: Text('contain (전체 보이기)')),
                DropdownMenuItem(
                    value: BoxFit.cover, child: Text('cover (꽉 채우기/잘림)')),
                DropdownMenuItem(
                    value: BoxFit.fill, child: Text('fill (비율 무시)')),
                DropdownMenuItem(value: BoxFit.fitWidth, child: Text('fitWidth')),
                DropdownMenuItem(
                    value: BoxFit.fitHeight, child: Text('fitHeight')),
                DropdownMenuItem(
                    value: BoxFit.scaleDown, child: Text('scaleDown')),
                DropdownMenuItem(value: BoxFit.none, child: Text('none (원본 크기)')),
              ],
              onChanged: (v) {
                if (v != null) c.setBoxFit(v);
              },
            ),
            const Divider(height: 24),
            // 재생 종료 정책
            const Text('재생 종료 정책'),
            const SizedBox(height: 8),
            SegmentedButton<PlaybackEndMode>(
              segments: const [
                ButtonSegment(
                    value: PlaybackEndMode.loop,
                    label: Text('반복'),
                    icon: Icon(Icons.repeat)),
                ButtonSegment(
                    value: PlaybackEndMode.once,
                    label: Text('1회'),
                    icon: Icon(Icons.looks_one)),
              ],
              selected: {c.endMode},
              onSelectionChanged: (s) => c.setEndMode(s.first),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '1회 모드: 재생이 끝나면 플레이어를 해제하고 메모리 변화를 관찰합니다.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
            const Divider(height: 24),
            // 디버그 HUD
            SwitchListTile(
              value: c.hudVisible,
              onChanged: (_) => c.toggleHud(),
              title: const Text('디버그 HUD'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            // 디코딩 (CPU/GPU 전환) — mpv 지원 엔진(Windows)만
            if (c.supportsMpvOptions) ...[
              const Divider(height: 24),
              const Text('디코딩 (hwdec)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'no',
                      label: Text('CPU'),
                      icon: Icon(Icons.memory)),
                  ButtonSegment(
                      value: 'auto-safe',
                      label: Text('GPU'),
                      icon: Icon(Icons.bolt)),
                  ButtonSegment(value: 'auto', label: Text('자동')),
                ],
                selected: {_hwdecSelected(c)},
                onSelectionChanged:
                    c.nativeAvailable ? (s) => c.setHwdec(s.first) : null,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'CPU = 소프트웨어 디코딩(호환성↑·CPU 사용↑)\n'
                  'GPU = 하드웨어 디코딩(CPU 사용↓·GPU 디코드 엔진 사용)\n'
                  '자동 = 가능하면 GPU 사용',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '현재 디코더: ${c.videoInfo.hwdec ?? '-'}  '
                  '(요청 ${c.hwdecOption.requestedValue ?? '-'} / 적용 ${c.hwdecOption.effectiveValue ?? '-'})',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
            // GPU (내장/외장) — 정보 표시 + Windows 설정 안내 (인앱 전환은 미지원)
            if (Platform.isWindows && c.availableGpus.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('GPU (내장/외장)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...c.availableGpus.map((g) => Text('• $g',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white70))),
              const SizedBox(height: 6),
              const Text(
                '인앱 GPU 전환은 렌더 D3D11 디바이스가 제거되어 불안정합니다. '
                '특정 GPU로 디코딩/재생을 테스트하려면 Windows 앱별 그래픽 설정에서 '
                '이 앱을 "고성능(외장)/절전(내장)"으로 지정한 뒤 앱을 재시작하세요.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _openGraphicsSettings,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Windows 그래픽 설정 열기'),
              ),
            ],
            // 창 해상도 (Windows 전용). 전체화면은 상단 AppBar/ESC.
            if (Platform.isWindows) ...[
              const Divider(height: 24),
              const Text('창 해상도',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const WindowControlsSection(),
            ],
            // mpv 옵션 (mpv 지원 엔진만)
            if (c.supportsMpvOptions) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text('mpv 옵션 (기본 / 적용값)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  // 모든 옵션을 기본값으로 복원
                  TextButton.icon(
                    onPressed:
                        c.nativeAvailable ? () => c.resetAllOptions() : null,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('기본값 복원', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MpvOptionsSection(controller: c),
            ],
            const Divider(height: 24),
            // 엔진 정보
            const Text('엔진', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              c.engineLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            // 1회 모드 메모리 해제 결과
            if (c.isCompleted) ...[
              const Divider(height: 24),
              const Text(
                '재생 종료 — 메모리 해제',
                style: TextStyle(
                    color: Colors.amberAccent, fontWeight: FontWeight.bold),
              ),
              Text('해제 전: ${_mb(c.memBeforeDisposeBytes)}',
                  style: const TextStyle(fontSize: 12)),
              Text('해제 후: ${_mb(c.memAfterDisposeBytes)}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  String _mb(int? bytes) => (bytes == null || bytes <= 0)
      ? '-'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}
