# 비디오 재생 퍼포먼스 테스트 앱 — 제품 요구사항 정의서 (PRD)

| 항목 | 내용 |
|---|---|
| 문서명 | 비디오 재생 퍼포먼스 테스트 랩 PRD |
| 버전 | v1.0 (구현 반영) |
| 작성일 | 2026-06-29 |
| 상태 | Phase 0~4 구현 완료 (Windows 빌드/Android APK 빌드 검증) |
| 대상 플랫폼 | Windows 데스크톱(우선), Android 실기기 |
| 프레임워크 | Flutter (Dart SDK ^3.12.2) |

---

## 1. 개요 및 목적

Flutter로 **다양한 컨테이너·코덱·해상도의 비디오를 재생하면서, 재생 가능 여부와 성능 지표를 실시간으로
관찰**하는 "비디오 재생 성능 테스트 랩" 앱을 만든다.

- 탐색기에서 비디오 파일을 선택하면 화면에 재생한다.
- 재생 중인 영상의 **코덱·해상도·디코더 정보 + 실시간 성능 지표**를 비디오 위 오버레이 HUD로 보여준다.
- **media_kit(mpv) 옵션(특히 CPU/GPU 디코딩)을 런타임에 바꿔가며 재생 변화를 직접 확인**한다.
- 현재 PC의 하드웨어 사양(CPU/GPU/RAM)도 함께 표시한다.

핵심 가치: "이 영상이 이 환경에서 잘 재생되는가, 옵션을 바꾸면 성능이 어떻게 달라지는가"를 한 화면에서
실험·관찰할 수 있는 도구.

---

## 2. 대상 사용자 / 사용 시나리오

- **대상**: 코덱·하드웨어 디코딩 성능을 검증하려는 개발자/QA(본인).
- **주 시나리오 — 단일 영상 심층 분석**:
  1. 파일 선택 → 2. 재생 → 3. HUD로 지표 관찰 → 4. mpv 옵션(예: hwdec) 변경 → 5. 변화 재관찰 →
  6. (선택) 1회 재생 종료 후 메모리 해제 확인.

---

## 3. 지원 범위

- **플랫폼**: Windows 데스크톱(우선 구현), Android 실기기(후속).
- **컨테이너**: mp4, mkv, webm, mov, ts 등 (mpv/FFmpeg 지원 범위).
- **코덱**: H.264, H.265/HEVC, AV1, VP9, MPEG-4 등.
- **해상도**: SD ~ 8K 및 **비정규 종횡비/초광각 해상도**(예: 9152×2288).
  - mpv는 임의 해상도를 허용한다.
  - 단, 초고해상도는 하드웨어 디코딩(hwdec) 가능 여부와 VRAM 한계가 성능에 직접 영향을 주므로,
    HUD의 해상도/디코더/드롭 지표로 그 영향을 가시화한다.

---

## 4. 기능 요구사항 (FR)

- **FR-1 파일 선택**: `file_selector`로 네이티브 탐색기를 열어 단일 비디오 파일 선택(확장자 필터).
  (※ `file_picker`는 win32 ^5.9.0을 요구해 media_kit/device_info_plus의 win32 6.x와 충돌 → `file_selector` 채택)
- **FR-2 비디오 렌더링**: 프로그램 창 크기 안에서 `BoxFit` 옵션
  (contain/cover/fill/fitWidth/fitHeight/scaleDown/none)을 선택해 적용. 레터박스 배경색 옵션 제공.
  (`media_kit_video`의 `Video(controller, fit: ...)` 활용)
- **FR-3 디버그 HUD(오버레이)**: 비디오 위에 사양·정보·지표를 `Stack` 오버레이로 표시.
  **켜고/끄기 토글**(버튼 + 단축키), 위치/투명도 조절 가능. 끄면 순수 재생 화면.
- **FR-4 실시간 성능 지표**: HUD 내 표시, 약 0.5~1초 주기로 갱신. (§5 참조)
- **FR-5 현재 영상 정보**: 코덱, 컨테이너, 해상도/종횡비, 프레임레이트, 비트레이트, 컬러스페이스/HDR,
  오디오 코덱/채널, 길이, 현재 사용 중인 하드웨어 디코더(`hwdec-current`).
- **FR-6 media_kit/mpv 옵션 컨트롤 패널**:
  - 큐레이션한 주요 옵션의 **기본값 표시**(시작 시 `get_property`로 읽음).
  - 런타임 변경(드롭다운/토글/입력): hwdec, video-sync, deinterlace, cache/demuxer 버퍼,
    스케일러(scale/dscale), framedrop, audio-channels 등.
  - **요청값 vs 실제 적용값 구분 표시**: 변경 후 `get_property`로 되읽어 비교
    (예: hwdec를 요청했으나 플랫폼이 거부하면 실제값이 다를 수 있음).
  - 각 옵션·선택지에 **한글 설명/기대효과**를 함께 표시(현재 선택값의 의미를 즉시 안내).
- **FR-7 CPU/GPU 디코딩 토글(핵심)**: `hwdec=no`(소프트웨어/CPU) ↔ `auto-safe`/`auto`(하드웨어/GPU).
  Windows는 d3d11va/nvdec, Android는 mediacodec. 전환 후 디코드 FPS·드롭·`hwdec-current`로 효과 확인.
- **FR-8 PC 하드웨어 사양 표시**: CPU 모델/코어 수, GPU 이름, 총 RAM.
  (Phase 1은 `device_info_plus`+`system_info2`로 가능한 범위, GPU 이름은 Phase 2 네이티브 채널.)
- **FR-9 Windows 창 제어**: `window_manager`로 전체화면(타이틀바 숨김 + 최대화 방식, AppBar/설정 패널도 숨김,
  **ESC로 해제**) + 창 크기를 프리셋(FHD/QHD/4K)·커스텀 해상도로 변경.
  (※ `setFullScreen`은 일부 환경에서 창이 사라지는 문제로 `setTitleBarStyle(hidden)`+`maximize` 방식 채택)
- **FR-10 엔진 경로(플랫폼별)**: 공통 재생 API는 `video_player_media_kit 2.0.0`.
  Windows = media_kit 백엔드(심층 기능 ON), Android = 네이티브 ExoPlayer(기본 지표). 동일 영상으로 비교.
- **FR-11 재생 컨트롤 UI**: 재생/일시정지 버튼, 시크 가능한 프로그레스 바(버퍼링 구간 표시),
  버퍼링 인디케이터(스피너/상태), 현재 시간/총 길이 표시.
- **FR-12 재생 종료 정책 + 메모리 관찰**: 두 모드 선택 —
  (a) **반복(루프) 재생**, (b) **1회 재생 후 종료**.
  종료 시 플레이어를 dispose/리소스 해제하고, 해제 전/후 **메모리(RSS) 변화를 HUD/로그로 관찰**
  (메모리 누수·정리 검증이 목적).
- **FR-13 GPU(어댑터) 선택**(Windows): DXGI로 내장/외장 GPU를 열거해 드롭다운 제공. 선택 시 mpv `d3d11-adapter`를
  설정하고 현재 영상을 **깨끗하게 재오픈**해 적용. HUD GPU 표시도 선택한 GPU로 갱신.
  (※ 런타임 어댑터 전환은 크래시 → 재오픈 방식. 외장 GPU는 렌더 GPU와 달라 **hwdec를 copy 모드**로 둬야 안정적.)
- **FR-14 패널/HUD 토글**: 디버그 HUD는 버튼으로, **설정 패널은 버튼 + `F1` 키**로 열고 닫기(기본 열림,
  전체화면 진입 시 자동 숨김, 전체화면에서도 F1로 토글).

---

## 5. 성능 지표 정의 & 수집 방법

| 지표 | 출처 | API / mpv 속성 | 단계 |
|---|---|---|---|
| 화면(UI) FPS | Flutter | `SchedulerBinding.addTimingsCallback` → `FrameTiming` 간격 | P1 |
| 디코드/표시 FPS | mpv | `estimated-vf-fps`, `container-fps`, `estimated-display-fps` | P1 |
| 드롭/지연 프레임 | mpv | `frame-drop-count`, `decoder-frame-drop-count`, `vo-delayed-frame-count` | P1 |
| 비디오/오디오 비트레이트 | mpv | `video-bitrate`, `audio-bitrate` | P1 |
| 코덱/컨테이너/색공간 | mpv | `video-codec`/`video-format`, `file-format`, `audio-codec`, `video-params/*` | P1 |
| 현재 HW 디코더 | mpv | `hwdec-current`, `hwdec-interop` | P1 |
| 메모리(프로세스 RSS) | dart:io | `ProcessInfo.currentRss` (앱 전체 = Flutter + mpv) | P1 |
| 하드웨어 스펙 | 패키지 | `device_info_plus`(총 RAM·코어), `system_info2`(코어·아키텍처) | P1 |
| **CPU 사용률 %** | 네이티브 채널 | Win: `GetProcessTimes`/PDH · Android: `/proc/self/stat` 델타 | **P2** |
| **GPU 사용률 %** | 네이티브 채널 | Win: PDH `GPU Engine` 카운터(/NVML) · Android: 사실상 불가 → 대체 | **P2** |
| **GPU 이름** | 네이티브 채널 | Win: DXGI/WMI · Android: `GL_RENDERER` | **P2** |

> **플랫폼 한계(정직한 명시)**
> - **mpv 기반 지표**(디코드 FPS·드롭·비트레이트·코덱·hwdec)는 **Windows(media_kit) 전용**이다.
>   Android(ExoPlayer)에서는 `VideoPlayerValue` 수준(해상도·길이·위치·버퍼링)만 가용하다.
> - **CPU%/GPU%/GPU명 네이티브 채널 구현 완료**(Windows C++): CPU%=`GetProcessTimes`, GPU%=PDH `GPU Engine`
>   카운터를 **현재 프로세스(PID) 한정 합산**, GPU명=DXGI. Android CPU%는 `/proc/self/stat`(순수 Dart).
> - **GPU%는 디코딩만의 지표가 아니다**: CPU 디코딩이어도 렌더링은 GPU라 0이 아니며, GPU 디코딩 효과는
>   CPU%·`hwdec-current`로 확인하는 것이 정확하다. Android GPU%는 벤더 비공개로 미수집.
> - 메모리(RSS)는 프로세스 전체(Flutter UI + mpv) 합산값이며, 디코딩 단독 사용량이 아니다.

---

## 6. 기술 아키텍처

### 6.1 패키지 구조 (로컬 vendoring)

```
flutter_video_player_app/
├── packages/
│   ├── video_player_media_kit/  # 공통 재생 계층(2.0.0). Windows=media_kit, Android=ExoPlayer
│   │                            #  └ Windows 경로에서 내부 media_kit Player를 외부로 노출하도록 커스텀
│   ├── media_kit/               # Windows 백엔드. mpv 지표/옵션 노출 헬퍼 추가 + 한글 주석
│   └── media_kit_video/         # 비디오 위젯(BoxFit fit)
├── pubspec.yaml                 # 위 3종 path 의존성 + media_kit_libs_windows_video는 pub.dev
└── lib/ ...
```

- Dart 레벨 패키지 3종을 `packages/`에 로컬 복사(vendoring)하여 소스 수정·한글 주석 추가가 가능하게 한다.
- 네이티브 바이너리(`media_kit_libs_windows_video`, mpv/FFmpeg .dll)는 수정 대상이 아니므로 pub.dev에서 그대로 사용.
- Android는 ExoPlayer 경로라 media_kit 네이티브 libs가 불필요하다.

### 6.2 재생 통합 계층

- 앱은 `video_player`의 `VideoPlayerController` API로 재생을 통일한다.
- **Windows**: vendored 브릿지가 내부적으로 media_kit `Player`를 생성한다. 이 Player 핸들을 앱에 노출(커스텀)해
  mpv 속성을 직접 제어한다.
- **Android**: 네이티브 ExoPlayer 사용 → 기본 `VideoPlayerValue` 지표만 제공.
- 공통 추상화 `PlaybackController`: open/play/pause/seek/loop/dispose + 지표 스트림.
  내부에서 플랫폼별 mpv 핸들 유무를 분기하고, HUD는 가용한 지표만 표시한다.

### 6.3 mpv 접근(Windows)

- media_kit `Player.platform as NativePlayer`의 `setProperty` / `getProperty` / `observeProperty` 활용.
- vendoring으로 정확한 시그니처를 확정하고 필요한 헬퍼를 추가한다.

### 6.4 플랫폼 채널 (Phase 2)

- `windows/runner`(C++)에 CPU%/GPU%/GPU 이름 채널을 추가한다.
- 이후 Android(`android/.../MainActivity.kt`, Kotlin/JNI)에 CPU%(`/proc`) 채널을 추가한다.

---

## 7. 화면 설계

- **메인 영역**: 비디오(BoxFit 적용) + 위에 오버레이 HUD(토글).
- **컨트롤/패널**: 파일 선택, 엔진 경로 표시, BoxFit 선택, 재생 컨트롤(재생/일시정지/시크/버퍼링),
  재생 종료 정책(반복/1회), mpv 옵션 컨트롤 패널(기본값/요청값/적용값), Windows 창 제어.
- **HUD 구성**: ① PC 하드웨어 사양 ② 실시간 성능 지표 ③ 현재 영상 정보, 3개 섹션.

---

## 8. 비기능 요구사항 / 코드 컨벤션

- 지표 수집이 재생 성능에 주는 오버헤드를 최소화한다(폴링 주기 조절, 타이머/isolate 분리).
- 옵션 변경 실패·코덱 미지원 시 명확한 에러/상태를 표시하고 크래시하지 않는다.
- **코드 컨벤션**: 심플하고 읽기 쉬운 코드. **한줄 한글 주석을 적극 활용**(의도/이유 중심).
  과도한 추상화를 지양하고, 요청 범위 밖 변경을 하지 않는다(CLAUDE.md 규칙 준수).

---

## 9. 구현 로드맵 (Windows 우선) — **Phase 0~4 전부 완료**

- ✅ **Phase 0 — 세팅(Windows)**: video_player_media_kit 2.0.0 + media_kit(+video) vendoring,
  pubspec path 의존성, `media_kit_libs_windows_video`, `flutter run -d windows` 빌드 확인.
- **Phase 1 — MVP(Windows)**: 파일 선택 → 재생, 재생 컨트롤(재생/일시정지/시크 프로그레스/버퍼링),
  반복 ↔ 1회 재생 모드 + 종료 시 dispose & 메모리 관찰, BoxFit, HUD 토글,
  mpv 지표(디코드 FPS·드롭·비트레이트·코덱·hwdec) + 메모리(RSS) + 화면 FPS + 하드웨어 스펙(가능 범위).
- **Phase 2 — 옵션/디코딩/창(Windows)**: mpv 옵션 컨트롤 패널(기본/요청/적용값), CPU/GPU 디코딩 토글,
  `window_manager` 풀스크린·해상도 변경.
- **Phase 3 — 네이티브 지표(Windows)**: `windows/runner` C++ 채널로 실제 CPU%/GPU%/GPU 이름.
- **Phase 4 — Android**: ExoPlayer 경로(video_player_media_kit Android 설정), 기본 지표 + CPU%(`/proc`) 채널,
  Windows와 동작 비교.

---

## 10. 리스크 / 미해결 사항 (구현 중 확정된 사항 포함)

- **확정 패키지 버전**: video_player_media_kit 2.0.0, media_kit 1.2.6, media_kit_video 2.0.1,
  media_kit_libs_windows_video 1.0.11, file_selector(win32 충돌로 file_picker 대체), window_manager 0.5.1,
  device_info_plus 13.2.0, system_info2 4.1.0. (3종 패키지는 `packages/`에 vendoring, `dependency_overrides`로 단일 소스 고정)
- **전체화면**: `window_manager.setFullScreen`이 일부 환경(멀티모니터/고DPI)에서 창이 사라짐
  → `setTitleBarStyle(hidden)`+`maximize` 방식으로 대체(작업표시줄은 남음).
- **외장 GPU 선택**: 런타임 어댑터 전환은 크래시 → 재오픈 방식. 렌더 GPU와 다른 외장 GPU로 디코딩하려면
  **hwdec를 copy 모드(d3d11va-copy/auto-copy)** 로 둬야 안정적(zero-copy는 교차 어댑터에서 크래시 가능).
- **접근성(AX) 콘솔 스팸**: 고빈도 UI 갱신이 Windows 접근성 트리를 압도해 `accessibility_bridge` 에러가
  쏟아짐 → notifyListeners 스로틀(~11Hz) + 동적 UI `ExcludeSemantics`로 차단(개발 도구라 a11y 비핵심).
- **빌드 모드**: debug(JIT)/release(AOT) 산출물을 같은 `build/`에서 섞으면 엔진 초기화 실패 → 모드 변경 시 `flutter clean`.
- **Android**: 스토리지 권한, content URI → 실경로 변환, mediacodec 코덱 한계. Android GPU%는 미수집(벤더 비공개).
- **초고해상도**(9152×2288 등): hwdec 미지원 시 소프트웨어 폴백으로 성능 저하 → 지표로 관찰.

---

## 11. 용어 / 참고

- **hwdec**: mpv의 하드웨어 디코딩 설정. `no`=CPU(소프트웨어), `auto-safe`/`auto`=GPU(하드웨어).
- **RSS**: Resident Set Size, 프로세스가 실제 점유한 물리 메모리.
- **mpv**: media_kit가 내부적으로 사용하는 미디어 엔진(libmpv).
- 참고: media_kit, video_player_media_kit, mpv 속성 문서(`mpv.io`).
