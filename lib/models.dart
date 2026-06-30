// Phase 1 데이터 모델 모음

/// 재생 종료 정책
enum PlaybackEndMode {
  loop, // 반복(루프) 재생
  once, // 1회 재생 후 종료(메모리 해제 관찰용)
}

extension PlaybackEndModeLabel on PlaybackEndMode {
  // UI 표시용 한글 라벨
  String get label => this == PlaybackEndMode.loop ? '반복 재생' : '1회 재생 후 종료';
}

/// 실시간 성능 지표 (주기적으로 갱신)
class PlaybackMetrics {
  final double? decodeFps; // mpv estimated-vf-fps (디코드/표시 FPS)
  final double? containerFps; // mpv container-fps (원본 프레임레이트)
  final int? frameDrops; // mpv frame-drop-count (출력 단계 드롭)
  final int? decoderDrops; // mpv decoder-frame-drop-count (디코더 드롭)
  final double? videoBitrate; // mpv video-bitrate (bps)
  final double? audioBitrate; // mpv audio-bitrate (bps)
  final double screenFps; // Flutter 렌더 FPS
  final int memoryBytes; // 프로세스 RSS (앱 전체 = Flutter + mpv)
  final double? cpuUsage; // 프로세스 CPU 사용률 % (네이티브 채널)
  final double? gpuUsage; // 전체 GPU 사용률 % (네이티브 채널)

  const PlaybackMetrics({
    this.decodeFps,
    this.containerFps,
    this.frameDrops,
    this.decoderDrops,
    this.videoBitrate,
    this.audioBitrate,
    this.screenFps = 0,
    this.memoryBytes = 0,
    this.cpuUsage,
    this.gpuUsage,
  });

  static const empty = PlaybackMetrics();
}

/// 현재 영상 정보 (로드 시 1회 + 가끔 갱신)
class VideoInfo {
  final String? codec; // mpv video-codec
  final String? container; // mpv file-format
  final int? width;
  final int? height;
  final String? audioCodec; // mpv audio-codec
  final String? hwdec; // mpv hwdec-current (현재 하드웨어 디코더)
  final String? pixelFormat; // mpv video-params/pixelformat

  const VideoInfo({
    this.codec,
    this.container,
    this.width,
    this.height,
    this.audioCodec,
    this.hwdec,
    this.pixelFormat,
  });

  static const empty = VideoInfo();

  // 해상도 문자열 (예: 1920 x 1080)
  String get resolution =>
      (width != null && height != null) ? '$width x $height' : '-';
}

/// PC 하드웨어 사양 (앱 시작 시 1회 조회)
class SystemSpecs {
  final String cpuModel; // CPU 모델명
  final int cpuCores; // 논리 코어 수
  final int totalRamBytes; // 총 물리 메모리
  final String gpuName; // GPU 이름 (Phase 2: 네이티브 채널)
  final String machine; // 컴퓨터/OS 라벨

  const SystemSpecs({
    this.cpuModel = '-',
    this.cpuCores = 0,
    this.totalRamBytes = 0,
    this.gpuName = '-',
    this.machine = '-',
  });

  static const empty = SystemSpecs();
}

/// mpv 옵션 1개 (기본값/요청값/적용값을 추적)
class MpvOption {
  final String name; // mpv 속성명
  final String label; // UI 표시 라벨
  final List<String> choices; // 선택지
  final String description; // 옵션이 무엇을 하는지(한글)
  final Map<String, String> choiceInfo; // 선택지별 의미/기대효과(한글)
  final String mpvDefault; // 표시/복원용 기본값(로드 전·읽기 실패 시 사용)
  String? defaultValue; // 로드 시 실제 읽은 초기값(= 기본값)
  String? requestedValue; // 사용자가 요청한 값
  String? effectiveValue; // 실제 적용값(setProperty 후 되읽음)

  MpvOption({
    required this.name,
    required this.label,
    required this.choices,
    this.description = '',
    this.choiceInfo = const {},
    this.mpvDefault = '',
  });

  // 표시/복원에 쓸 기본값: 실제 읽은 값 우선, 없으면 하드코딩 기본값
  String? get baseValue => defaultValue ?? (mpvDefault.isEmpty ? null : mpvDefault);
}

/// 컨트롤 패널에 노출할 mpv 옵션 큐레이션 목록 (한글 설명 포함)
List<MpvOption> defaultMpvOptions() => [
      MpvOption(
        name: 'hwdec',
        label: '하드웨어 디코딩(hwdec)',
        mpvDefault: 'no',
        description: '디코딩을 CPU(소프트웨어) ↔ GPU(하드웨어)로 전환. GPU 디코딩은 CPU 사용을 크게 낮춤.',
        choices: const [
          'no', 'auto', 'auto-safe', 'auto-copy',
          'd3d11va', 'd3d11va-copy', 'nvdec', 'nvdec-copy',
        ],
        choiceInfo: const {
          'no': 'CPU(소프트웨어) 디코딩. 호환성 최고, CPU 사용↑.',
          'auto': '가능하면 하드웨어 디코딩 자동 선택.',
          'auto-safe': '검증된 안전한 하드웨어 디코더만 자동 사용(권장).',
          'auto-copy': '하드웨어 디코딩 후 프레임을 CPU로 복사(호환성↑, 약간 느림).',
          'd3d11va': 'Direct3D11 비디오 가속 — Windows 권장 하드웨어 디코딩.',
          'd3d11va-copy': 'd3d11va + CPU 복사(필터/스크린샷 호환).',
          'nvdec': 'NVIDIA GPU 전용 하드웨어 디코더.',
          'nvdec-copy': 'nvdec + CPU 복사(호환성↑).',
        },
      ),
      MpvOption(
        name: 'video-sync',
        label: '비디오 동기화',
        mpvDefault: 'audio',
        description: '비디오/오디오 동기 방식. display-* 는 화면이 더 부드럽지만 부하가 늘 수 있음.',
        choices: const [
          'audio', 'display-resample', 'display-resample-vdrop',
          'display-vdrop', 'display-desync',
        ],
        choiceInfo: const {
          'audio': '오디오 시계에 맞춤(기본, 안정적).',
          'display-resample': '디스플레이 주사율에 맞춰 리샘플(부드러움↑, 약간 부하).',
          'display-resample-vdrop': 'display-resample + 필요 시 프레임 드롭.',
          'display-vdrop': '디스플레이 동기 + 프레임 드롭.',
          'display-desync': '디스플레이 동기, 비동기 허용(실험/테스트용).',
        },
      ),
      MpvOption(
        name: 'framedrop',
        label: '프레임 드롭',
        mpvDefault: 'vo',
        description: '재생이 밀릴 때 프레임을 버리는 정책. 부하 테스트 시 드롭 발생을 관찰.',
        choices: const ['no', 'vo', 'decoder', 'decoder+vo'],
        choiceInfo: const {
          'no': '드롭 안 함(끊겨도 모든 프레임 표시).',
          'vo': '출력이 늦으면 프레임 드롭(기본).',
          'decoder': '디코더 단계에서 드롭(과부하 시 따라잡기).',
          'decoder+vo': '디코더+출력 양쪽 드롭.',
        },
      ),
      MpvOption(
        name: 'deinterlace',
        label: '디인터레이스',
        mpvDefault: 'no',
        description: '인터레이스(짝/홀수 줄) 영상의 줄무늬 제거 여부.',
        choices: const ['no', 'yes'],
        choiceInfo: const {
          'no': '끔(프로그레시브 영상은 이게 기본).',
          'yes': '인터레이스 영상의 줄무늬 제거(필요 시).',
        },
      ),
      MpvOption(
        name: 'interpolation',
        label: '보간(interpolation)',
        mpvDefault: 'no',
        description: '프레임 보간으로 모션을 부드럽게. display 동기 모드에서 효과, GPU 부하↑.',
        choices: const ['no', 'yes'],
        choiceInfo: const {
          'no': '끔(기본).',
          'yes': '프레임 보간 켜기(video-sync=display-* 필요, GPU 부하 증가).',
        },
      ),
      MpvOption(
        name: 'scale',
        label: '업스케일러',
        mpvDefault: 'bilinear',
        description: '영상을 키울 때(업스케일) 보간 알고리즘. 아래로 갈수록 화질↑·부하↑.',
        choices: const ['bilinear', 'spline36', 'lanczos', 'ewa_lanczossharp'],
        choiceInfo: const {
          'bilinear': '가장 빠름, 품질 낮음.',
          'spline36': '품질/속도 균형(권장).',
          'lanczos': '선명, 약간 무거움.',
          'ewa_lanczossharp': '가장 선명, 가장 무거움.',
        },
      ),
      MpvOption(
        name: 'dscale',
        label: '다운스케일러',
        mpvDefault: 'bilinear',
        description: '영상을 줄일 때(다운스케일) 알고리즘.',
        choices: const ['bilinear', 'mitchell', 'catmull_rom', 'lanczos'],
        choiceInfo: const {
          'bilinear': '빠름, 무난.',
          'mitchell': '부드러움(권장).',
          'catmull_rom': '선명한 편.',
          'lanczos': '가장 선명.',
        },
      ),
      MpvOption(
        name: 'cache',
        label: '캐시',
        mpvDefault: 'auto',
        description: '디먹서 캐시 사용 여부. 로컬 파일은 보통 영향이 적고, 네트워크/대용량에 유리.',
        choices: const ['auto', 'yes', 'no'],
        choiceInfo: const {
          'auto': '자동(기본).',
          'yes': '캐시 사용(네트워크/대용량에 유리).',
          'no': '캐시 끔.',
        },
      ),
    ];
