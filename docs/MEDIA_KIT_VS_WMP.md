# media_kit(mpv) vs Windows Media Player — 재생/디코딩 방식 비교

이 앱(Flutter + media_kit)의 비디오 재생 방식이 Windows 기본 플레이어(Windows Media Player /
"미디어 플레이어", Media Foundation 기반)와 어떻게 다른지 정리한다. 디버그 HUD에도 요약이 표시된다.

## 한눈에 보기

| 항목 | media_kit (이 앱) | Windows Media Player |
|---|---|---|
| 엔진 | libmpv + **FFmpeg 내장 디코더** | **Media Foundation**(OS 프레임워크) |
| 코덱 출처 | 앱에 **번들된 FFmpeg** (OS 설치와 무관) | **OS + 설치된 코덱 확장**(HEVC/AV1 확장 등) |
| 코덱 범위 | H.264/H.265/AV1/VP9 등 광범위, 기기 무관 일관 | 기기/Windows 버전/설치 코덱에 따라 상이 |
| 하드웨어 디코딩 | `hwdec` 옵션으로 **SW(CPU)↔HW(GPU) 수동 전환**(d3d11va/nvdec 등) | **DXVA2/D3D11 자동** 사용, 사용자 제어 거의 없음 |
| 렌더링 | libmpv GPU 출력 → **Flutter 텍스처**로 합성 | Media Foundation 파이프라인 → 시스템 표면 |
| 설정/계측 | mpv 옵션·속성으로 **풍부한 튜닝·지표 계측**(이 앱의 목적) | 소비자용, 노출되는 옵션·지표 제한적 |
| 이식성 | 자체 번들 → **크로스플랫폼 동일 동작** | **Windows 종속** |

## 핵심 차이 3가지 (HUD 요약)

1. **코덱**: media_kit는 FFmpeg 내장 디코더를 써서 OS에 코덱이 설치돼 있지 않아도 재생한다.
   WMP는 OS(Media Foundation)와 설치된 코덱 확장에 의존하므로 같은 파일이라도 기기마다 재생 여부가 다를 수 있다.
2. **디코딩 제어**: media_kit는 `hwdec`로 소프트웨어(CPU) ↔ 하드웨어(GPU, d3d11va/nvdec) 디코딩을
   수동 전환하고 그 차이를 계측할 수 있다(본 앱 Phase 2의 핵심). WMP는 DXVA를 자동으로 쓰며 사용자 제어가 거의 없다.
3. **일관성/계측**: media_kit는 자체 번들이라 플랫폼 간 동작이 일관되고, mpv 속성으로 디코드 FPS·드롭·
   비트레이트 등 내부 지표를 읽어 성능을 정량 비교할 수 있다. WMP는 소비자용이라 이런 계측이 어렵다.

## 왜 이 앱은 media_kit를 쓰는가

- "이 코덱/해상도가 이 하드웨어에서 어떻게 재생되는가"를 **재현 가능하고 일관되게** 측정하기 위해.
- CPU 전용 vs GPU 디코딩을 **직접 전환**하며 성능 차이를 관찰하기 위해(WMP로는 불가).
- mpv 옵션을 바꿔가며 재생 변화를 실험하기 위해.

## 주의 (해석상 한계)

- media_kit가 hwdec를 끄면(`hwdec=no`) 소프트웨어 디코딩이라 WMP(자동 HW)보다 CPU 사용량이 높게 보일 수 있다.
  → 공정 비교를 하려면 hwdec 설정을 명시적으로 맞춰야 한다.
- 본 앱의 메모리(RSS) 지표는 프로세스 전체(Flutter + mpv) 합산값으로, WMP 단일 프로세스와 1:1 비교 대상이 아니다.

> 참고: mpv 속성·옵션 문서 https://mpv.io/manual/master/ , Media Foundation https://learn.microsoft.com/windows/win32/medfound/
