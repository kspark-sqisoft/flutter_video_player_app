import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:system_info2/system_info2.dart';

import 'models.dart';
import 'native_metrics.dart';

/// PC 하드웨어 사양을 한 번 조회한다 (앱 시작 시 호출).
Future<SystemSpecs> loadSystemSpecs() async {
  String cpuModel = '알 수 없음';
  int cores = 0;
  int ramBytes = 0;
  String machine = '-';
  // GPU 이름: Windows 네이티브 채널(DXGI)에서 조회
  final gpuName = await NativeMetrics.gpuName() ?? '알 수 없음';

  // system_info2: CPU 모델 / 논리 코어 수 / 총 메모리
  try {
    final list = SysInfo.cores; // List<CoreInfo>
    cores = list.length;
    if (list.isNotEmpty && list.first.name.isNotEmpty) {
      cpuModel = list.first.name;
    }
    ramBytes = SysInfo.getTotalPhysicalMemory();
  } catch (_) {
    // 조회 실패 시 기본값 유지
  }

  // device_info_plus: 코어 수 / RAM 보강 + 머신 라벨
  try {
    if (Platform.isWindows) {
      final w = await DeviceInfoPlugin().windowsInfo;
      if (cores == 0) cores = w.numberOfCores;
      if (ramBytes == 0) ramBytes = w.systemMemoryInMegabytes * 1024 * 1024;
      machine = '${w.productName} (${w.computerName})';
    } else if (Platform.isAndroid) {
      final a = await DeviceInfoPlugin().androidInfo;
      machine = '${a.manufacturer} ${a.model} (Android ${a.version.release})';
      // Android은 CPU 모델명 대신 ABI/하드웨어 식별자 사용
      if (cpuModel == '알 수 없음') {
        cpuModel = a.supportedAbis.isNotEmpty ? a.supportedAbis.first : a.hardware;
      }
    }
  } catch (_) {}

  return SystemSpecs(
    cpuModel: cpuModel,
    cpuCores: cores,
    totalRamBytes: ramBytes,
    gpuName: gpuName,
    machine: machine,
  );
}
