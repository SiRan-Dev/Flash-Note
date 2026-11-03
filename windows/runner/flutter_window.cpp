#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Arbitrary ID used by RegisterHotKey; must be unique within the process.
constexpr int kQuickCaptureHotkeyId = 0x464E;
// MOD_NOREPEAT suppresses auto-repeat while the combination is held down.
constexpr UINT kHotkeyNoRepeat = 0x4000;

bool ReadIntArgument(const flutter::EncodableMap& arguments,
                     const std::string& key,
                     int* value) {
  auto it = arguments.find(flutter::EncodableValue(key));
  if (it == arguments.end()) {
    return false;
  }
  if (const auto* int_value = std::get_if<int32_t>(&it->second)) {
    *value = *int_value;
    return true;
  }
  if (const auto* long_value = std::get_if<int64_t>(&it->second)) {
    *value = static_cast<int>(*long_value);
    return true;
  }
  return false;
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
  RegisterHotkeyChannel();
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
  UnregisterQuickCaptureHotkey();
  hotkey_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::RegisterHotkeyChannel() {
  hotkey_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.sirandev.flashnote/hotkey",
          &flutter::StandardMethodCodec::GetInstance());
  hotkey_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "register") {
          int modifiers = 0;
          int virtual_key = 0;
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr ||
              !ReadIntArgument(*arguments, "modifiers", &modifiers) ||
              !ReadIntArgument(*arguments, "key", &virtual_key)) {
            result->Error("INVALID_ARGUMENTS",
                          "modifiers and key are required");
            return;
          }
          bool registered =
              RegisterQuickCaptureHotkey(modifiers, virtual_key);
          result->Success(flutter::EncodableValue(registered));
        } else if (call.method_name() == "unregister") {
          UnregisterQuickCaptureHotkey();
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
}

bool FlutterWindow::RegisterQuickCaptureHotkey(int modifiers,
                                               int virtual_key) {
  UnregisterQuickCaptureHotkey();
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return false;
  }
  if (!RegisterHotKey(hwnd, kQuickCaptureHotkeyId,
                      static_cast<UINT>(modifiers) | kHotkeyNoRepeat,
                      static_cast<UINT>(virtual_key))) {
    return false;
  }
  hotkey_registered_ = true;
  return true;
}

void FlutterWindow::UnregisterQuickCaptureHotkey() {
  if (!hotkey_registered_) {
    return;
  }
  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    UnregisterHotKey(hwnd, kQuickCaptureHotkeyId);
  }
  hotkey_registered_ = false;
}

void FlutterWindow::ShowAndFocusWindow() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(hwnd);
  BringWindowToTop(hwnd);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_HOTKEY &&
      static_cast<int>(wparam) == kQuickCaptureHotkeyId) {
    ShowAndFocusWindow();
    if (hotkey_channel_) {
      flutter::EncodableValue arguments(flutter::EncodableMap{});
      hotkey_channel_->InvokeMethod("onHotkey", &arguments);
    }
    return 0;
  }

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
