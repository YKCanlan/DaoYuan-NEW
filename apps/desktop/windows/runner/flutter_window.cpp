#include "flutter_window.h"

#include <optional>
#include <cstdlib>
#include <cstdio>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::string ReadUtf8File(const std::wstring& path) {
  FILE* file = nullptr;
  if (_wfopen_s(&file, path.c_str(), L"rb") != 0 || file == nullptr) {
    return {};
  }
  std::string data;
  char buffer[4096];
  size_t count = 0;
  while ((count = fread(buffer, 1, sizeof(buffer), file)) > 0) {
    data.append(buffer, count);
  }
  fclose(file);
  return data;
}

int JsonIntAfterKey(const std::string& json, const char* key) {
  const std::string needle = std::string("\"") + key + "\"";
  const auto key_at = json.find(needle);
  if (key_at == std::string::npos) return 0;
  const auto colon = json.find(':', key_at + needle.size());
  if (colon == std::string::npos) return 0;
  return std::atoi(json.c_str() + colon + 1);
}

void KillPidTree(int pid) {
  if (pid <= 0) return;
  wchar_t system_dir[MAX_PATH];
  if (GetSystemDirectoryW(system_dir, MAX_PATH) == 0) return;
  std::wstring command = L"\"";
  command += system_dir;
  command += L"\\taskkill.exe\" /PID ";
  command += std::to_wstring(pid);
  command += L" /T /F";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
    return;
  }
  WaitForSingleObject(process.hProcess, 3000);
  CloseHandle(process.hProcess);
  CloseHandle(process.hThread);
}

// Portable builds keep host.json beside the exe. Kill that tree if Dart
// does not reach its own shutdown path.
void KillBundledHost() {
  wchar_t exe[MAX_PATH];
  const DWORD length = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) return;
  std::wstring path(exe, length);
  const auto slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) return;
  path.resize(slash);
  path += L"\\runtime\\host.json";
  const std::string json = ReadUtf8File(path);
  if (json.empty()) return;
  const int wrapper = JsonIntAfterKey(json, "wrapperPid");
  const int server = JsonIntAfterKey(json, "pid");
  if (wrapper > 0) KillPidTree(wrapper);
  if (server > 0 && server != wrapper) KillPidTree(server);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  KillBundledHost();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
