#include "system_metrics.h"

#include <dxgi.h>

#include <vector>

namespace {
// FILETIME -> 64-bit integer (100ns units).
ULONGLONG FileTimeToU64(const FILETIME& ft) {
  ULARGE_INTEGER u;
  u.LowPart = ft.dwLowDateTime;
  u.HighPart = ft.dwHighDateTime;
  return u.QuadPart;
}

// Wide string -> UTF-8.
std::string WideToUtf8(const wchar_t* w) {
  if (!w) return std::string();
  int len = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
  if (len <= 0) return std::string();
  std::string s(len - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w, -1, &s[0], len, nullptr, nullptr);
  return s;
}
}  // namespace

SystemMetrics::SystemMetrics() {
  SYSTEM_INFO info;
  GetSystemInfo(&info);
  num_processors_ = info.dwNumberOfProcessors ? info.dwNumberOfProcessors : 1;

  // Prepare the GPU PDH query (ignore failures -> GPU% returns 0).
  if (PdhOpenQueryW(nullptr, 0, &gpu_query_) == ERROR_SUCCESS) {
    if (PdhAddEnglishCounterW(gpu_query_,
                              L"\\GPU Engine(*)\\Utilization Percentage", 0,
                              &gpu_counter_) == ERROR_SUCCESS) {
      PdhCollectQueryData(gpu_query_);  // first (baseline) sample
      gpu_ready_ = true;
    }
  }
}

SystemMetrics::~SystemMetrics() {
  if (gpu_query_) {
    PdhCloseQuery(gpu_query_);
    gpu_query_ = nullptr;
  }
}

double SystemMetrics::GetCpuUsage() {
  FILETIME creation, exit, kernel, user;
  if (!GetProcessTimes(GetCurrentProcess(), &creation, &exit, &kernel, &user)) {
    return 0.0;
  }
  ULARGE_INTEGER now_proc;
  now_proc.QuadPart = FileTimeToU64(kernel) + FileTimeToU64(user);

  FILETIME now_sys_ft;
  GetSystemTimeAsFileTime(&now_sys_ft);
  ULARGE_INTEGER now_sys;
  now_sys.QuadPart = FileTimeToU64(now_sys_ft);

  // First call: store baseline only and return 0.
  if (!cpu_initialized_) {
    prev_proc_ = now_proc;
    prev_sys_ = now_sys;
    cpu_initialized_ = true;
    return 0.0;
  }

  double proc_delta =
      static_cast<double>(now_proc.QuadPart - prev_proc_.QuadPart);
  double sys_delta = static_cast<double>(now_sys.QuadPart - prev_sys_.QuadPart);
  prev_proc_ = now_proc;
  prev_sys_ = now_sys;

  if (sys_delta <= 0.0) return 0.0;
  // Total available CPU time = elapsed wall time * number of cores.
  double usage = (proc_delta / sys_delta) / num_processors_ * 100.0;
  if (usage < 0.0) usage = 0.0;
  if (usage > 100.0) usage = 100.0;
  return usage;
}

double SystemMetrics::GetGpuUsage() {
  if (!gpu_ready_) return 0.0;
  if (PdhCollectQueryData(gpu_query_) != ERROR_SUCCESS) return 0.0;

  DWORD buffer_size = 0;
  DWORD item_count = 0;
  // First pass: query the required buffer size.
  PDH_STATUS status = PdhGetFormattedCounterArrayW(
      gpu_counter_, PDH_FMT_DOUBLE, &buffer_size, &item_count, nullptr);
  if (status != PDH_MORE_DATA || buffer_size == 0) return 0.0;

  std::vector<BYTE> buffer(buffer_size);
  PDH_FMT_COUNTERVALUE_ITEM_W* items =
      reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buffer.data());
  // Second pass: read values and sum all engine instances.
  status = PdhGetFormattedCounterArrayW(gpu_counter_, PDH_FMT_DOUBLE,
                                        &buffer_size, &item_count, items);
  if (status != ERROR_SUCCESS) return 0.0;

  // Only sum engine instances that belong to the current process.
  // PDH instance names look like "pid_1234_luid_..._engtype_3D".
  std::wstring prefix = L"pid_" + std::to_wstring(GetCurrentProcessId()) + L"_";
  double total = 0.0;
  for (DWORD i = 0; i < item_count; i++) {
    if (items[i].FmtValue.CStatus != ERROR_SUCCESS) continue;
    if (items[i].szName &&
        std::wstring(items[i].szName).find(prefix) != std::wstring::npos) {
      total += items[i].FmtValue.doubleValue;
    }
  }
  if (total > 100.0) total = 100.0;
  if (total < 0.0) total = 0.0;
  return total;
}

std::string SystemMetrics::GetGpuName() {
  IDXGIFactory1* factory = nullptr;
  if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                reinterpret_cast<void**>(&factory)))) {
    return std::string();
  }
  std::string name;
  IDXGIAdapter1* adapter = nullptr;
  // Use adapter 0 (the primary GPU) description.
  if (factory->EnumAdapters1(0, &adapter) == S_OK) {
    DXGI_ADAPTER_DESC1 desc;
    if (SUCCEEDED(adapter->GetDesc1(&desc))) {
      name = WideToUtf8(desc.Description);
    }
    adapter->Release();
  }
  factory->Release();
  return name;
}

std::vector<std::string> SystemMetrics::GetGpuList() {
  std::vector<std::string> list;
  IDXGIFactory1* factory = nullptr;
  if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1),
                                reinterpret_cast<void**>(&factory)))) {
    return list;
  }
  IDXGIAdapter1* adapter = nullptr;
  for (UINT i = 0; factory->EnumAdapters1(i, &adapter) == S_OK; i++) {
    DXGI_ADAPTER_DESC1 desc;
    if (SUCCEEDED(adapter->GetDesc1(&desc))) {
      // Skip software adapters (e.g. Microsoft Basic Render Driver).
      if (!(desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)) {
        list.push_back(WideToUtf8(desc.Description));
      }
    }
    adapter->Release();
    adapter = nullptr;
  }
  factory->Release();
  return list;
}
