#ifndef RUNNER_SYSTEM_METRICS_H_
#define RUNNER_SYSTEM_METRICS_H_

#include <windows.h>
#include <pdh.h>
#include <pdhmsg.h>

#include <string>
#include <vector>

// Helper that collects CPU/GPU usage and the GPU name (Windows only).
class SystemMetrics {
 public:
  SystemMetrics();
  ~SystemMetrics();

  // Current process CPU usage (%), measured since the previous call.
  double GetCpuUsage();
  // Total GPU usage (%), summed PDH GPU Engine counters (clamped 0..100).
  double GetGpuUsage();
  // Primary GPU adapter name (via DXGI).
  std::string GetGpuName();
  // All hardware GPU adapter names (via DXGI), software adapters excluded.
  std::vector<std::string> GetGpuList();

 private:
  // CPU baseline (previous sample).
  bool cpu_initialized_ = false;
  ULARGE_INTEGER prev_proc_ = {};
  ULARGE_INTEGER prev_sys_ = {};
  DWORD num_processors_ = 1;

  // GPU PDH query.
  PDH_HQUERY gpu_query_ = nullptr;
  PDH_HCOUNTER gpu_counter_ = nullptr;
  bool gpu_ready_ = false;
};

#endif  // RUNNER_SYSTEM_METRICS_H_
