import 'package:flutter/material.dart';

import '../models.dart';
import '../playback_controller.dart';

/// mpv 옵션 컨트롤: 각 옵션을 기본값/요청값/적용값과 함께 표시하고 변경한다.
class MpvOptionsSection extends StatelessWidget {
  const MpvOptionsSection({super.key, required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.nativeAvailable) {
      return const Text(
        'mpv 옵션은 Windows(media_kit)에서만 사용 가능합니다.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: c.mpvOptions.map((o) => _optionTile(c, o)).toList(),
    );
  }

  Widget _optionTile(PlaybackController c, MpvOption o) {
    // 드롭다운 현재값: 요청값 > 적용값 > 기본값 순
    final current = o.requestedValue ?? o.effectiveValue ?? o.baseValue;
    // 요청값과 적용값이 다르면(플랫폼이 거부 등) 강조
    final mismatch =
        o.requestedValue != null && o.requestedValue != o.effectiveValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(o.label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          // 옵션 설명(무엇을 하는지)
          if (o.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 2),
              child: Text(o.description,
                  style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ),
          DropdownButton<String>(
            value: o.choices.contains(current) ? current : null,
            isExpanded: true,
            isDense: true,
            hint: Text(current ?? '-', style: const TextStyle(fontSize: 12)),
            items: o.choices
                .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v, style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) c.applyOption(o, v);
            },
          ),
          // 현재 선택한 값의 의미/기대효과
          if (current != null && (o.choiceInfo[current] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('▸ $current : ${o.choiceInfo[current]}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.lightBlueAccent)),
            ),
          Row(
            children: [
              Expanded(
                child: Text('기본: ${o.baseValue ?? '-'}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.white54)),
              ),
              Expanded(
                child: Text('적용: ${o.effectiveValue ?? '-'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: mismatch ? Colors.orangeAccent : Colors.white54,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
