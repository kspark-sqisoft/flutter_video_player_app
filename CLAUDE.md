# CLAUDE.md — flutter_video_player_app

이 파일은 이 저장소에서 작업하는 Claude Code를 위한 프로젝트 가이드다.
상세 요구사항의 단일 출처(SSOT)는 **[docs/PRD.md](docs/PRD.md)** 이며, 이 파일은 작업에 필요한
핵심 결정·규칙·명령 위주로 요약한다.

## 프로젝트 개요

다양한 컨테이너·코덱·해상도의 비디오를 재생하면서 **재생 가능 여부와 성능 지표를 실시간으로 관찰**하는
"비디오 재생 성능 테스트 랩" 앱. 탐색기로 영상을 고르면 재생하고, 비디오 위 오버레이 HUD로 코덱/디코더/
지표를 보여주며, **media_kit(mpv) 옵션(특히 CPU/GPU 디코딩)을 런타임에 바꿔가며 재생 변화를 확인**한다.

## 핵심 결정사항

| 항목 | 결정 |
|---|---|
| 대상 플랫폼 | **Windows 데스크톱(우선)** + Android 실기기(후속) |
| 재생 통합 계층 | **`video_player_media_kit 2.0.0`** (vendored) — Windows=media_kit 백엔드, Android=네이티브 ExoPlayer |
| 패키지 방식 | `packages/`에 Dart 패키지 3종(video_player_media_kit, media_kit, media_kit_video) **로컬 vendoring** |
| 네이티브 바이너리 | `media_kit_libs_windows_video`는 pub.dev 그대로. Android는 ExoPlayer라 media_kit libs 불필요 |
| 주 시나리오 | 단일 영상 심층 분석 |
| 지표 범위 | MVP 먼저 → OS 레벨 CPU%/GPU%/GPU명은 네이티브 채널로 Phase 2 |

## 아키텍처 (요약)

- 앱은 `video_player`의 `VideoPlayerController` API로 재생을 통일한다.
- **Windows**: vendored 브릿지가 내부 media_kit `Player`를 생성 → 그 핸들을 앱에 노출(커스텀)해
  mpv 속성을 직접 제어(`Player.platform as NativePlayer`의 `setProperty`/`getProperty`/`observeProperty`).
- **Android**: 네이티브 ExoPlayer → 기본 `VideoPlayerValue` 지표만.
- 공통 추상화 `PlaybackController`: open/play/pause/seek/loop/dispose + 지표 스트림.
  플랫폼별 mpv 핸들 유무를 분기하고 HUD는 가용 지표만 표시.
- **중요 한계**: mpv 기반 심층 지표(디코드 FPS·드롭·hwdec 등)는 **Windows 전용**.
  Android GPU%는 사실상 측정 불가 → hwdec/디코드 FPS/드롭으로 간접 표현.

## 디렉터리 구조 (목표)

```
packages/
  video_player_media_kit/   # 공통 재생 계층(2.0.0). Windows 경로에서 media_kit Player 노출 커스텀
  media_kit/                # Windows 백엔드. mpv 지표/옵션 노출 헬퍼 + 한글 주석
  media_kit_video/          # 비디오 위젯(BoxFit fit)
lib/                        # 앱 코드(재생 컨트롤러, HUD, 옵션 패널, 화면)
windows/runner/             # Phase 2: CPU%/GPU%/GPU명 플랫폼 채널(C++)
docs/PRD.md                 # 요구사항 단일 출처
```

## 빌드 / 실행

```bash
flutter pub get
flutter run -d windows      # 우선 타깃
flutter run -d <android-id> # 후속
flutter analyze             # 정적 분석
```

## 코드 컨벤션 (필수)

- **한국어로 답변/작업.** 코드 주석은 **한줄 한글 주석을 적극 활용**(의도·이유 중심).
- 심플하고 읽기 쉬운 코드. 과도한 추상화 금지.
- **요청 범위 밖 변경 금지.** 보안 취약점 없는 안전한 코드.
- vendored 패키지(`packages/**`)는 수정 가능하나, 변경 시 한글 주석으로 변경 의도를 남긴다.

## 구현 로드맵 (Windows 우선)

- **Phase 0** — 세팅: 패키지 vendoring + pubspec path 의존성 + `flutter run -d windows` 빌드 확인.
- **Phase 1** — MVP: 파일 선택→재생, 재생 컨트롤(재생/일시정지/시크/버퍼링), 반복↔1회 재생+종료 시
  dispose & 메모리 관찰, BoxFit, HUD 토글, mpv 지표 + 메모리(RSS) + 화면 FPS + 하드웨어 스펙.
- **Phase 2** — 옵션/디코딩/창: mpv 옵션 패널(기본/요청/적용값), CPU/GPU 디코딩 토글, `window_manager` 창 제어.
- **Phase 3** — 네이티브 지표: `windows/runner` C++ 채널로 CPU%/GPU%/GPU명.
- **Phase 4** — Android: ExoPlayer 경로 + 기본 지표 + CPU%(`/proc`) 채널.

> 현재 상태: **Phase 4 완료 — 4개 Phase 전부 구현·빌드 검증 완료.** 플랫폼 분기 추상화(Windows=media_kit,
> Android=video_player/ExoPlayer). Android 기본 지표(VideoPlayerValue)+CPU%(/proc/self/stat).
> Windows 빌드 ✓ / Android `app-debug.apk` 빌드 ✓ / `flutter analyze` ✓.
> (참고: wakelock_plus의 KGP 경고는 media_kit_video 전이 의존성에서 나오는 무해한 경고)

### 재생 엔진 추상화 (Phase 4)
- `playback_controller.dart` — 추상 `PlaybackController`(공통 상태·지표 타이머·화면FPS) + `MediaKitPlaybackController`(Windows) + `createPlaybackController()` 팩토리
- `exo_playback_controller.dart` — `ExoPlaybackController`(Android, video_player). BoxFit은 FittedBox로 적용
- 엔진별 분기: `engineLabel`/`supportsMpvOptions`/`nativeAvailable`/`buildVideoView()`/`readMpvExtras()`
- Android 지표: CPU%는 `native_metrics.dart`의 `/proc/self/stat` 순수 Dart, GPU%는 미수집(벤더 비공개)
- 위젯은 베이스 타입만 참조. settings_panel은 `supportsMpvOptions`/`Platform.isWindows`로 섹션 가드

### 네이티브 채널 (windows/runner)
- `system_metrics.{h,cpp}` — CPU%/GPU%/GPU명 수집 / `flutter_window.{h,cpp}` — `video_perf/metrics` MethodChannel 등록
- CMakeLists에 `system_metrics.cpp` + `pdh.lib`/`dxgi.lib` 추가 / Dart: `lib/native_metrics.dart`
- 채널 메서드: `sample`(cpu/gpu), `gpuName`, `gpuList`(DXGI 어댑터 목록)
- **GPU%는 현재 프로세스(PID) 엔진만 합산**(시스템 전체 아님). GPU 디코딩이어도 렌더링은 GPU라 0이 아님.
- **GPU 선택**: 드롭다운 → mpv `d3d11-adapter` 설정 + 영상 재오픈. 하드웨어 디코딩(hwdec=d3d11va) GPU를 지정(렌더링 GPU는 ANGLE가 별도 결정).
- ⚠️ **C++ 파일 주석은 반드시 영어**(MSVC가 한글 주석으로 빌드 실패). Dart/문서는 한글 유지.

### 코드 구조 (lib/)
- `main.dart` — 초기화(media_kit + window_manager) + 앱 루트 / `player_screen.dart` — 좌(비디오+HUD+컨트롤)+우(설정)
- `playback_controller.dart` — media_kit Player 래퍼 + mpv getProperty 폴링(0.5s) + 화면 FPS + 메모리 + 옵션/hwdec(setProperty)
- `system_info_service.dart` — device_info_plus/system_info2로 PC 사양 / `models.dart` — 데이터 모델(+MpvOption)
- `widgets/` — video_view(BoxFit)·playback_controls·debug_hud(엔진 비교)·settings_panel·mpv_options_section·window_controls_section

### 학습 메모
- **ListTile 계열(SwitchListTile 등)을 `Container(color:)`(=ColoredBox) 안에 두면** 매 프레임 assertion이
  throw되고 AXTree 에러까지 유발 → **`Material(color:)`로 감싸야 함**(settings_panel 참조).
- mpv 옵션은 `setProperty` 후 `getProperty`로 되읽어 요청값≠적용값을 구분(플랫폼 거부 감지).

### vendoring 메모 (중요)
- vendored 패키지가 전이 의존성을 hosted로 선언해 path 충돌이 나므로, pubspec의 `dependency_overrides`로
  `media_kit`/`media_kit_video`/`video_player_media_kit`를 로컬 path로 강제한다(이 override 제거 금지).
- 패키지 재다운로드: `dart pub cache add <pkg> --version <ver>` 후 캐시에서 `packages/`로 복사.
- **파일 선택은 `file_selector` 사용**(file_picker 8~11.x는 win32 ^5.9.0 요구 → media_kit/device_info_plus의
  win32 6.x와 충돌하므로 사용 불가).
- mpv 심층 접근: `(player.platform as NativePlayer).getProperty/setProperty` (media_kit가 public export).

### 문서
- `docs/PRD.md`(요구사항 SSOT), `docs/MEDIA_KIT_VS_WMP.md`(media_kit vs Windows Media Player 비교).

## 주의 / 미해결

- 패키지 버전은 `flutter pub get` 시점에 pub.dev 최신 안정으로 확정·고정.
  `video_player_media_kit`는 **2.0.0 고정**(플랫폼별 백엔드 초기화 API는 소스 받은 뒤 확정).
- Android: 스토리지 권한, content URI→실경로 변환, mediacodec 코덱 한계.
- 메모리(RSS)는 프로세스 전체(Flutter+mpv) 합산값(디코딩 단독 아님).
