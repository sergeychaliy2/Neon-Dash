#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <cstdlib>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Returns true when a launcher already chose a renderer.
//
// `flutter run --enable-impeller` / `--no-enable-impeller` arrives as an engine
// switch in the environment: FLUTTER_ENGINE_SWITCHES holds a count, and
// FLUTTER_ENGINE_SWITCH_<N>, indexed from 1, holds each switch. Honouring it
// keeps those flags usable for re-measuring this decision later.
bool RendererChosenByLauncher() {
  char* count_text = nullptr;
  size_t size = 0;
  if (::_dupenv_s(&count_text, &size, "FLUTTER_ENGINE_SWITCHES") != 0 ||
      count_text == nullptr) {
    return false;
  }
  const long count = ::strtol(count_text, nullptr, 10);
  ::free(count_text);

  for (long i = 1; i <= count; ++i) {
    const std::string name = "FLUTTER_ENGINE_SWITCH_" + std::to_string(i);
    char* value = nullptr;
    if (::_dupenv_s(&value, &size, name.c_str()) != 0 || value == nullptr) {
      continue;
    }
    const bool mentions_impeller =
        std::string(value).find("enable-impeller") != std::string::npos;
    ::free(value);
    if (mentions_impeller) {
      return true;
    }
  }
  return false;
}

// Chooses the renderer for this app on Windows.
//
// A measured decision, not a preference. Profiled on this project with the
// autopilot driving a full scene, Flutter 3.47.7, Windows 11:
//
//   Impeller (OpenGLESSDF)   raster p50 5.7-6.9 ms, p95 ~9 ms, 4-19% late
//   Skia                     raster p50 0.38 ms,    p95 0.53 ms, 0 late
//
// Roughly fifteenfold on the thread that was the bottleneck. The scene is a few
// dozen anti-aliased translucent shapes redrawn from scratch every frame, and
// Impeller's OpenGL ES path on Windows tessellates that far more expensively
// than Skia does.
//
// Scope and shelf life. Windows only: Android runs Impeller on Vulkan, where
// the picture is different and nothing here applies. And Skia is on its way out
// of Flutter, so when an SDK drops the fallback this has to be re-measured and
// the scene simplified, not silently deleted.
void SelectRenderer(flutter::DartProject& project) {
  if (RendererChosenByLauncher()) {
    return;
  }
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  SelectRenderer(project);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"neon_dash", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
