# flutter_video_player_app — 비디오 재생 성능 테스트 랩

다양한 컨테이너·코덱·해상도의 비디오를 재생하면서 **재생 가능 여부와 성능 지표를 실시간으로 관찰**하는
Flutter 데스크톱/모바일 앱. 탐색기로 영상을 고르면 재생하고, 비디오 위 오버레이 **HUD**로 코덱/디코더/
지표를 보여주며, **media_kit(mpv) 옵션(특히 CPU/GPU 디코딩)을 런타임에 바꿔가며** 재생 변화를 확인한다.

> 상세 요구사항의 단일 출처(SSOT)는 [docs/PRD.md](docs/PRD.md), 작업 가이드는 [CLAUDE.md](CLAUDE.md) 참고.

## 주요 기능

- **파일 선택 → 재생**: 네이티브 탐색기(`file_selector`)로 비디오 선택, 다양한 컨테이너 지원(mp4/mkv/webm/mov/ts 등).
- **재생 컨트롤**: 재생/일시정지, 시크 가능한 프로그레스 바, 버퍼링 표시.
- **BoxFit 화면 맞춤**: contain/cover/fill/fitWidth/fitHeight/scaleDown/none.
- **디버그 HUD(토글)**: PC 사양 + 실시간 지표 + 영상 정보 + media_kit(mpv) vs Windows Media Player 비교.
- **실시간 지표**: 화면 FPS, 디코드/컨테이너 FPS, 프레임 드롭(출력/디코더), 비트레이트, 메모리(RSS), CPU%/GPU%.
- **mpv 옵션 패널**: hwdec, video-sync, framedrop, deinterlace, interpolation, scale/dscale, cache를
  **기본값 / 요청값 / 적용값**과 함께 표시·변경. **기본값 일괄 복원** 버튼 제공.
- **CPU/GPU 디코딩 토글**: `hwdec` 전환(CPU=`no`, GPU=`auto-safe`, 자동=`auto`) 후 효과를 지표로 확인.
- **하드웨어 스펙 표시**: CPU 모델/코어, 총 RAM, GPU 이름.
- **창 제어(Windows)**: 전체화면(타이틀바 숨김·ESC로 해제), 창 해상도 변경. 설정 패널 토글(F1).
- **재생 종료 정책**: 반복(loop) ↔ 1회(once) 재생 — 1회 모드는 종료 시 dispose 후 메모리 변화 관찰.

## 아키텍처

- 공통 추상화 `PlaybackController` 위에서 플랫폼별 엔진을 분기한다.
  - **Windows**: `media_kit`(libmpv/FFmpeg) 직접 사용. `NativePlayer`의 `getProperty`/`setProperty`로
    mpv 심층 지표·옵션 제어 → 디코드 FPS·드롭·hwdec 등 **Windows 전용 지표** 제공.
  - **Android**: 네이티브 `video_player`(ExoPlayer). 기본 `VideoPlayerValue` 지표 + CPU%(`/proc/self/stat`).
- **네이티브 지표 채널(Windows, C++)**: `windows/runner`의 `video_perf/metrics` MethodChannel —
  CPU%(`GetProcessTimes`), GPU%(PDH GPU Engine, 현재 PID), GPU 이름(DXGI).

### 디렉터리 구조

```
packages/                      # 로컬 vendoring(소스 수정·한글 주석 가능)
  video_player_media_kit/      #   공통 재생 계층(2.0.0)
  media_kit/                   #   Windows 백엔드(mpv)
  media_kit_video/             #   비디오 위젯(BoxFit)
lib/                           # 앱 코드
  main.dart                    #   초기화(media_kit + window_manager)
  player_screen.dart           #   좌(비디오+HUD+컨트롤) + 우(설정 패널)
  playback_controller.dart     #   추상 컨트롤러 + MediaKit(Windows) + 팩토리
  exo_playback_controller.dart #   ExoPlaybackController(Android)
  native_metrics.dart          #   네이티브 지표 채널 / system_info_service.dart  # PC 사양
  models.dart                  #   데이터 모델(+MpvOption)
  widgets/                     #   video_view·playback_controls·debug_hud·settings_panel 등
windows/runner/                # CPU%/GPU%/GPU명 플랫폼 채널(C++)
docs/PRD.md                    # 요구사항 SSOT / docs/MEDIA_KIT_VS_WMP.md  # 비교 문서
```

## 빌드 / 실행

```bash
flutter pub get
flutter run -d windows --release   # 우선 타깃(Windows 데스크톱)
flutter run -d <android-id>        # 후속(Android 실기기)
flutter analyze                    # 정적 분석
```

> **참고**: vendored 패키지가 전이 의존성을 hosted로 선언해 path 충돌이 나므로, `pubspec.yaml`의
> `dependency_overrides`로 로컬 path를 강제한다(제거 금지). 파일 선택은 win32 버전 충돌 때문에
> `file_picker` 대신 `file_selector`를 사용한다.

## 플랫폼별 한계

- mpv 기반 심층 지표(디코드 FPS·드롭·hwdec 등)는 **Windows 전용**. Android는 기본 지표만.
- GPU%는 **현재 프로세스(PID) 엔진만 합산**(시스템 전체 아님). GPU 디코딩이어도 렌더링은 GPU라 0이 아니다.
- **인앱 GPU 전환은 미지원**: 렌더 D3D11 디바이스가 제거되어 불안정 → Windows 앱별 그래픽 설정에서
  지정 후 앱 재시작으로 테스트한다.
- 메모리(RSS)는 프로세스 전체(Flutter+mpv) 합산값.

## 개발 메모

- 코드 주석은 한글(의도·이유 중심). 단, **C++ 파일 주석은 영어**(MSVC가 한글 주석으로 빌드 실패).
- `ListTile` 계열은 `Container(color:)` 대신 `Material(color:)`로 감싼다(매 프레임 assertion 방지).
- mpv 옵션은 `setProperty` 후 `getProperty`로 되읽어 **요청값 ≠ 적용값**(플랫폼 거부)을 구분한다.

## 라이선스

vendored 패키지(`packages/**`)는 각 패키지의 원 라이선스를 따른다(media_kit 등).
