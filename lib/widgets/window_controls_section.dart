import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 창 해상도 변경 (Windows 전용). 전체화면은 상단 AppBar 버튼/ESC로 제어.
class WindowControlsSection extends StatefulWidget {
  const WindowControlsSection({super.key});

  @override
  State<WindowControlsSection> createState() => _WindowControlsSectionState();
}

class _WindowControlsSectionState extends State<WindowControlsSection> {
  final _wCtrl = TextEditingController();
  final _hCtrl = TextEditingController();

  // 창 해상도 프리셋
  static const _presets = <String, Size>{
    'HD 1280×720': Size(1280, 720),
    'FHD 1920×1080': Size(1920, 1080),
    'QHD 2560×1440': Size(2560, 1440),
    '4K 3840×2160': Size(3840, 2160),
  };

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  // 창 크기 변경 (최대화 상태면 해제 후 적용) + 화면 중앙 이동
  Future<void> _resize(Size size) async {
    await windowManager.unmaximize();
    await windowManager.setSize(size);
    await windowManager.center();
  }

  void _applyCustom() {
    final w = double.tryParse(_wCtrl.text);
    final h = double.tryParse(_hCtrl.text);
    if (w != null && h != null && w >= 200 && h >= 200) {
      _resize(Size(w, h));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const Text(
        '창 제어는 Windows에서만 사용 가능합니다.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('창 해상도 프리셋', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _presets.entries
              .map((e) => ActionChip(
                    label: Text(e.key, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _resize(e.value),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        const Text('커스텀 해상도', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _wCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'W', isDense: true),
              ),
            ),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6), child: Text('×')),
            Expanded(
              child: TextField(
                controller: _hCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'H', isDense: true),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(onPressed: _applyCustom, child: const Text('적용')),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('전체화면은 상단 ⛶ 버튼, 해제는 ESC.',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      ],
    );
  }
}
