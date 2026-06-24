#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/SarahRoseLives/InmarScope.git"
LIBACARS_URL="https://github.com/szpajder/libacars.git"
IMGUI_URL="https://github.com/ocornut/imgui.git"
IMPLOT_URL="https://github.com/epezent/implot.git"
ROOT="$(pwd)"
SRC="$ROOT/source/InmarScope"
BUILD="$ROOT/build"
RELEASE="$ROOT/release"

log() { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*"; exit 1; }

clone_or_update_dependency() {
  local name="$1"
  local url="$2"
  local path="$3"
  local required_file="$4"
  local branch="${5:-}"

  if [[ -f "$path/$required_file" ]]; then
    log "$name already present"
    return 0
  fi

  warn "$name is missing or incomplete; downloading it directly."
  rm -rf "$path"
  if [[ -n "$branch" ]]; then
    git clone --depth 1 --branch "$branch" "$url" "$path"
  else
    git clone --depth 1 "$url" "$path"
  fi

  if [[ ! -f "$path/$required_file" ]]; then
    fail "$name still missing required file: $required_file. Check GitHub/internet access, then run build.exe.bat again."
  fi
}

ensure_imgui_docking_branch() {
  local path="$1"
  # InmarScope uses Dear ImGui docking APIs. The regular/master ImGui branch
  # compiles imgui.cpp but does not define DockSpace/DockBuilder symbols.
  # Force the docking branch if the required symbols are absent.
  if [[ ! -f "$path/imgui.h" ]] || ! grep -q "ImGuiConfigFlags_DockingEnable" "$path/imgui.h"; then
    warn "Dear ImGui is present but it is not the docking branch; replacing it with ocornut/imgui docking."
    rm -rf "$path"
    git clone --depth 1 --branch docking "$IMGUI_URL" "$path"
  fi
  if ! grep -q "ImGuiConfigFlags_DockingEnable" "$path/imgui.h"; then
    fail "Dear ImGui docking branch could not be verified. InmarScope requires ImGui docking APIs."
  fi
}

if [[ "${MSYSTEM:-}" != "MINGW64" ]]; then
  echo "ERROR: This must run inside the MSYS2 MINGW64 environment."
  echo "The batch file sets MSYSTEM=MINGW64 automatically."
  exit 1
fi

log "Installing / verifying MSYS2 MinGW64 build dependencies"
pacman -S --needed --noconfirm \
  git \
  unzip \
  curl \
  mingw-w64-x86_64-toolchain \
  mingw-w64-x86_64-cmake \
  mingw-w64-x86_64-ninja \
  mingw-w64-x86_64-pkgconf \
  mingw-w64-x86_64-glfw \
  mingw-w64-x86_64-rtl-sdr \
  mingw-w64-x86_64-libusb \
  mingw-w64-x86_64-zstd \
  mingw-w64-x86_64-hackrf \
  mingw-w64-x86_64-libogg \
  mingw-w64-x86_64-libvorbis \
  mingw-w64-x86_64-zlib

mkdir -p "$ROOT/source"

# Important: always refresh the source tree. The earlier failed builders can leave
# empty third_party folders that Git will not reliably repair during an in-place update.
log "Cloning a clean InmarScope source tree"
rm -rf "$SRC"
git clone --recursive --depth 1 --shallow-submodules "$REPO_URL" "$SRC"

log "Synchronizing / updating any declared Git submodules"
git -C "$SRC" submodule sync --recursive || true
git -C "$SRC" submodule update --init --recursive --depth 1 || true

# Fallbacks for dependencies that are referenced by CMake but may not be present
# if GitHub submodules were not declared/fetched correctly.
clone_or_update_dependency "libacars" "$LIBACARS_URL" "$SRC/third_party/libacars" "CMakeLists.txt"
clone_or_update_dependency "Dear ImGui docking" "$IMGUI_URL" "$SRC/third_party/imgui" "imgui.cpp" "docking"
ensure_imgui_docking_branch "$SRC/third_party/imgui"
clone_or_update_dependency "ImPlot" "$IMPLOT_URL" "$SRC/third_party/implot" "implot.cpp"

log "Verifying required third_party source files before CMake"
required_files=(
  "$SRC/third_party/libacars/CMakeLists.txt"
  "$SRC/third_party/imgui/imgui.cpp"
  "$SRC/third_party/imgui/imgui_draw.cpp"
  "$SRC/third_party/imgui/imgui_tables.cpp"
  "$SRC/third_party/imgui/imgui_widgets.cpp"
  "$SRC/third_party/imgui/backends/imgui_impl_glfw.cpp"
  "$SRC/third_party/imgui/backends/imgui_impl_opengl3.cpp"
  "$SRC/third_party/implot/implot.cpp"
  "$SRC/third_party/implot/implot_items.cpp"
  "$SRC/third_party/jaero_dsp/DSP.cpp"
  "$SRC/third_party/mbelib"
  "$SRC/third_party/miniaudio"
)
for item in "${required_files[@]}"; do
  if [[ ! -e "$item" ]]; then
    fail "Required source item is missing: $item"
  fi
done


apply_cyberpunk_theme_patch() {
  local main_cpp="$SRC/src/main.cpp"
  if [[ ! -f "$main_cpp" ]]; then
    warn "Could not find src/main.cpp for cyberpunk theme patch; continuing without UI theme patch."
    return 0
  fi

  if grep -q "InmarScope Cyberpunk Theme Patch" "$main_cpp"; then
    log "Cyberpunk theme patch already applied"
    return 0
  fi

  log "Applying InmarScope Cyberpunk theme patch to the real UI"
  python - "$main_cpp" <<'PYTHEME'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
s = path.read_text(encoding='utf-8')

func = """

// InmarScope Cyberpunk Theme Patch - added by Windows Builder V7
static void ApplyInmarScopeCyberpunkTheme()
{
    ImGuiStyle& style = ImGui::GetStyle();
    ImVec4* colors = style.Colors;

    style.WindowRounding = 8.0f;
    style.ChildRounding = 7.0f;
    style.FrameRounding = 5.0f;
    style.PopupRounding = 7.0f;
    style.ScrollbarRounding = 8.0f;
    style.GrabRounding = 5.0f;
    style.TabRounding = 6.0f;
    style.WindowBorderSize = 1.0f;
    style.ChildBorderSize = 1.0f;
    style.PopupBorderSize = 1.0f;
    style.FrameBorderSize = 1.0f;
    style.TabBorderSize = 1.0f;
    style.WindowPadding = ImVec2(10.0f, 10.0f);
    style.FramePadding = ImVec2(8.0f, 5.0f);
    style.ItemSpacing = ImVec2(8.0f, 7.0f);
    style.ItemInnerSpacing = ImVec2(7.0f, 5.0f);

    colors[ImGuiCol_Text]                  = ImVec4(0.86f, 0.92f, 1.00f, 1.00f);
    colors[ImGuiCol_TextDisabled]          = ImVec4(0.42f, 0.38f, 0.60f, 1.00f);
    colors[ImGuiCol_WindowBg]              = ImVec4(0.025f, 0.015f, 0.055f, 1.00f);
    colors[ImGuiCol_ChildBg]               = ImVec4(0.035f, 0.020f, 0.080f, 0.98f);
    colors[ImGuiCol_PopupBg]               = ImVec4(0.035f, 0.020f, 0.075f, 0.98f);
    colors[ImGuiCol_Border]                = ImVec4(0.70f, 0.10f, 1.00f, 0.65f);
    colors[ImGuiCol_BorderShadow]          = ImVec4(0.00f, 0.90f, 1.00f, 0.18f);
    colors[ImGuiCol_FrameBg]               = ImVec4(0.075f, 0.035f, 0.130f, 1.00f);
    colors[ImGuiCol_FrameBgHovered]        = ImVec4(0.55f, 0.05f, 0.90f, 0.55f);
    colors[ImGuiCol_FrameBgActive]         = ImVec4(0.95f, 0.10f, 1.00f, 0.65f);
    colors[ImGuiCol_TitleBg]               = ImVec4(0.055f, 0.020f, 0.105f, 1.00f);
    colors[ImGuiCol_TitleBgActive]         = ImVec4(0.18f, 0.035f, 0.28f, 1.00f);
    colors[ImGuiCol_TitleBgCollapsed]      = ImVec4(0.025f, 0.015f, 0.055f, 0.90f);
    colors[ImGuiCol_MenuBarBg]             = ImVec4(0.040f, 0.015f, 0.075f, 1.00f);
    colors[ImGuiCol_ScrollbarBg]           = ImVec4(0.020f, 0.010f, 0.040f, 1.00f);
    colors[ImGuiCol_ScrollbarGrab]         = ImVec4(0.55f, 0.05f, 0.90f, 0.75f);
    colors[ImGuiCol_ScrollbarGrabHovered]  = ImVec4(0.00f, 0.85f, 1.00f, 0.85f);
    colors[ImGuiCol_ScrollbarGrabActive]   = ImVec4(1.00f, 0.90f, 0.00f, 0.95f);
    colors[ImGuiCol_CheckMark]             = ImVec4(0.00f, 0.95f, 1.00f, 1.00f);
    colors[ImGuiCol_SliderGrab]            = ImVec4(1.00f, 0.90f, 0.00f, 1.00f);
    colors[ImGuiCol_SliderGrabActive]      = ImVec4(1.00f, 0.25f, 0.95f, 1.00f);
    colors[ImGuiCol_Button]                = ImVec4(0.18f, 0.035f, 0.32f, 0.92f);
    colors[ImGuiCol_ButtonHovered]         = ImVec4(0.70f, 0.05f, 1.00f, 0.85f);
    colors[ImGuiCol_ButtonActive]          = ImVec4(0.00f, 0.85f, 1.00f, 0.90f);
    colors[ImGuiCol_Header]                = ImVec4(0.36f, 0.04f, 0.65f, 0.70f);
    colors[ImGuiCol_HeaderHovered]         = ImVec4(0.00f, 0.80f, 1.00f, 0.55f);
    colors[ImGuiCol_HeaderActive]          = ImVec4(1.00f, 0.84f, 0.00f, 0.70f);
    colors[ImGuiCol_Separator]             = ImVec4(0.00f, 0.85f, 1.00f, 0.55f);
    colors[ImGuiCol_SeparatorHovered]      = ImVec4(1.00f, 0.10f, 1.00f, 0.75f);
    colors[ImGuiCol_SeparatorActive]       = ImVec4(1.00f, 0.90f, 0.00f, 1.00f);
    colors[ImGuiCol_ResizeGrip]            = ImVec4(0.00f, 0.80f, 1.00f, 0.35f);
    colors[ImGuiCol_ResizeGripHovered]     = ImVec4(1.00f, 0.10f, 1.00f, 0.70f);
    colors[ImGuiCol_ResizeGripActive]      = ImVec4(1.00f, 0.90f, 0.00f, 0.95f);
    colors[ImGuiCol_Tab]                   = ImVec4(0.12f, 0.025f, 0.22f, 0.95f);
    colors[ImGuiCol_TabHovered]            = ImVec4(0.75f, 0.05f, 1.00f, 0.85f);
    colors[ImGuiCol_TabActive]             = ImVec4(0.20f, 0.05f, 0.42f, 1.00f);
    colors[ImGuiCol_TabUnfocused]          = ImVec4(0.055f, 0.020f, 0.105f, 1.00f);
    colors[ImGuiCol_TabUnfocusedActive]    = ImVec4(0.11f, 0.035f, 0.22f, 1.00f);
    colors[ImGuiCol_DockingPreview]        = ImVec4(0.00f, 0.90f, 1.00f, 0.55f);
    colors[ImGuiCol_DockingEmptyBg]        = ImVec4(0.015f, 0.010f, 0.035f, 1.00f);
    colors[ImGuiCol_PlotLines]             = ImVec4(0.00f, 0.92f, 1.00f, 1.00f);
    colors[ImGuiCol_PlotLinesHovered]      = ImVec4(1.00f, 0.88f, 0.00f, 1.00f);
    colors[ImGuiCol_PlotHistogram]         = ImVec4(0.95f, 0.10f, 1.00f, 1.00f);
    colors[ImGuiCol_PlotHistogramHovered]  = ImVec4(1.00f, 0.90f, 0.00f, 1.00f);
    colors[ImGuiCol_TableHeaderBg]         = ImVec4(0.13f, 0.030f, 0.22f, 1.00f);
    colors[ImGuiCol_TableBorderStrong]     = ImVec4(0.75f, 0.08f, 1.00f, 0.80f);
    colors[ImGuiCol_TableBorderLight]      = ImVec4(0.00f, 0.80f, 1.00f, 0.35f);
    colors[ImGuiCol_TableRowBg]            = ImVec4(0.030f, 0.015f, 0.065f, 1.00f);
    colors[ImGuiCol_TableRowBgAlt]         = ImVec4(0.060f, 0.025f, 0.105f, 1.00f);
    colors[ImGuiCol_TextSelectedBg]        = ImVec4(0.95f, 0.10f, 1.00f, 0.35f);
    colors[ImGuiCol_NavHighlight]          = ImVec4(0.00f, 0.92f, 1.00f, 1.00f);
    colors[ImGuiCol_ModalWindowDimBg]      = ImVec4(0.01f, 0.00f, 0.03f, 0.78f);
}
"""

insert_pos = s.find('int main(')
if insert_pos == -1:
    raise SystemExit('Could not find int main() in main.cpp')
s = s[:insert_pos] + func + '\n' + s[insert_pos:]

if 'ImGui::StyleColorsDark();' in s:
    s = s.replace('ImGui::StyleColorsDark();', 'ImGui::StyleColorsDark();\n    ApplyInmarScopeCyberpunkTheme();', 1)
elif 'ImGui::CreateContext();' in s:
    s = s.replace('ImGui::CreateContext();', 'ImGui::CreateContext();\n    ApplyInmarScopeCyberpunkTheme();', 1)
else:
    raise SystemExit('Could not find ImGui style/context call to apply cyberpunk theme')

path.write_text(s, encoding='utf-8')
PYTHEME
}


apply_decoder_audio_layout_patch() {
  local gui_cpp="$SRC/src/gui/gui_panels.cpp"
  if [[ ! -f "$gui_cpp" ]]; then
    warn "Could not find src/gui/gui_panels.cpp for decoder layout patch; continuing without this UI fix."
    return 0
  fi

  if grep -q "InmarScope Decoder Audio Layout Fix" "$gui_cpp"; then
    log "Decoder audio layout patch already applied"
    return 0
  fi

  log "Applying decoder Audio out layout fix"
  python - "$gui_cpp" <<'PYLAYOUT'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
s = path.read_text(encoding='utf-8')

# InmarScope Decoder Audio Layout Fix - added by Windows Builder V7
# 1) Give the left Control/Decoders dock a little more initial room. This reduces
#    right-edge clipping on normal 1366/1400/1536 wide Windows displays.
s = s.replace('DockBuilderSplitNode(dockId, ImGuiDir_Left, 0.32f, &left, &right)',
              'DockBuilderSplitNode(dockId, ImGuiDir_Left, 0.42f, &left, &right)')
s = s.replace('DockBuilderSplitNode(dockId, ImGuiDir_Left, 0.32f,&left,&right)',
              'DockBuilderSplitNode(dockId, ImGuiDir_Left, 0.42f,&left,&right)')

lines = s.splitlines()
out = []
changed = False
skip_sameline_until = -1

for i, line in enumerate(lines):
    stripped = line.strip()
    # If the audio output combo uses the visible label "Audio out", ImGui draws
    # the label to the right of the combo. On the current layout that can push
    # the refresh button into the dock divider. Convert it to a label above the
    # combo and use a hidden ImGui ID for the combo itself.
    if '"Audio out"' in line and ('Combo' in line or 'BeginCombo' in line):
        indent = line[:len(line) - len(line.lstrip())]
        out.append(indent + '// InmarScope Decoder Audio Layout Fix')
        out.append(indent + 'ImGui::TextUnformatted("Audio out");')
        line = line.replace('"Audio out"', '"##Audio out"', 1)
        changed = True
        skip_sameline_until = i + 14

    # Keep the audio refresh button on a new line instead of squeezing it against
    # the combo/label. This is deliberately local to the lines after Audio out.
    if i <= skip_sameline_until and stripped == 'ImGui::SameLine();':
        out.append(line.replace('ImGui::SameLine();', '/* V6 layout fix: refresh stays on next line */'))
        changed = True
        continue

    out.append(line)

s2 = '\n'.join(out) + ('\n' if s.endswith('\n') else '')
if not changed and 'Audio out' in s2:
    # Last-resort safeguard: mark the file so repeated runs don't stack patches.
    s2 = '// InmarScope Decoder Audio Layout Fix - marker only; no exact Audio out combo pattern found\n' + s2
elif changed:
    s2 = '// InmarScope Decoder Audio Layout Fix - active\n' + s2

path.write_text(s2, encoding='utf-8')
PYLAYOUT
}


apply_call_hunter_safe_mode_patch() {
  local main_cpp="$SRC/src/main.cpp"
  local app_h="$SRC/src/core/app.h"
  if [[ ! -f "$main_cpp" ]]; then
    warn "Could not find src/main.cpp for CallHunter safe-mode patch; continuing without it."
    return 0
  fi

  if grep -q "InmarScope CallHunter Safe Mode Patch" "$main_cpp"; then
    log "CallHunter safe-mode patch already applied"
    return 0
  fi

  log "Applying CallHunter safe-mode performance patch"
  python - "$main_cpp" "$app_h" <<'PYCALLHUNTER'
import pathlib, sys, re
main = pathlib.Path(sys.argv[1])
apph = pathlib.Path(sys.argv[2])
s = main.read_text(encoding='utf-8')

old = 'if (app.active->running()) updateCallHunter(app);'
new = """// InmarScope CallHunter Safe Mode Patch - throttle heavy scanner work
        static double __ims_last_callhunter_update = 0.0;
        if (app.active->running() && app.callHunterMode) {
            double __ims_now = glfwGetTime();
            if ((__ims_now - __ims_last_callhunter_update) >= 0.25) {
                updateCallHunter(app);
                __ims_last_callhunter_update = __ims_now;
            }
        } else if (!app.callHunterMode) {
            app.callHunterWarmup = 0;
        }"""
if old in s:
    s = s.replace(old, new, 1)
else:
    s2 = re.sub(r'if\s*\(\s*app\.active->running\(\)\s*\)\s*updateCallHunter\(app\)\s*;', new, s, count=1)
    if s2 == s:
        print('WARNING: exact updateCallHunter call not found; marker only')
    s = s2
main.write_text(s, encoding='utf-8')

if apph.exists():
    ah = apph.read_text(encoding='utf-8')
    if 'CallHunter Safe Mode Patch' not in ah and 'bool callHunterMode' in ah:
        ah = ah.replace('bool callHunterMode = false;', 'bool callHunterMode = false; // InmarScope CallHunter Safe Mode Patch')
        apph.write_text(ah, encoding='utf-8')
PYCALLHUNTER
}



apply_cyberpunk_theme_patch
apply_decoder_audio_layout_patch
apply_call_hunter_safe_mode_patch

log "Configuring CMake Release build"
rm -rf "$BUILD"
cmake -S "$SRC" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release

log "Building InmarScope.exe"
cmake --build "$BUILD" --parallel "$(nproc)"

log "Creating release folder"
rm -rf "$RELEASE"
mkdir -p "$RELEASE"

EXE_PATH=""
if [[ -f "$BUILD/InmarScope.exe" ]]; then
  EXE_PATH="$BUILD/InmarScope.exe"
else
  EXE_PATH="$(find "$BUILD" -type f -iname 'InmarScope.exe' | head -n 1 || true)"
fi

if [[ -z "$EXE_PATH" || ! -f "$EXE_PATH" ]]; then
  fail "Build completed, but InmarScope.exe was not found in the build folder."
fi

cp -f "$EXE_PATH" "$RELEASE/"
find "$(dirname "$EXE_PATH")" -maxdepth 1 -type f \( -iname "*.dll" -o -iname "*.exe" \) -exec cp -f {} "$RELEASE/" \;

# Copy common MinGW runtime DLLs if CMake did not copy them.
for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll glfw3.dll librtlsdr.dll libusb-1.0.dll libzstd.dll libhackrf.dll libogg-0.dll libvorbis-0.dll libvorbisenc-2.dll zlib1.dll; do
  if [[ -f "/mingw64/bin/$dll" && ! -f "$RELEASE/$dll" ]]; then
    cp -f "/mingw64/bin/$dll" "$RELEASE/" || true
  fi
done

# CMake may warn that WebView2Loader.dll is not in /mingw64/bin. InmarScope vendors
# the WebView2 SDK under third_party, so copy from there when available.
WEBVIEW_DLL="$SRC/third_party/webview2/build/native/x64/WebView2Loader.dll"
if [[ -f "$WEBVIEW_DLL" && ! -f "$RELEASE/WebView2Loader.dll" ]]; then
  cp -f "$WEBVIEW_DLL" "$RELEASE/" || true
elif [[ -f "/mingw64/bin/WebView2Loader.dll" && ! -f "$RELEASE/WebView2Loader.dll" ]]; then
  cp -f "/mingw64/bin/WebView2Loader.dll" "$RELEASE/" || true
else
  warn "WebView2Loader.dll was not found. If InmarScope later complains about WebView2, install Microsoft Edge WebView2 Runtime."
fi

cat > "$RELEASE/Run_InmarScope.bat" <<'RUNEOF'
@echo off
cd /d "%~dp0"
start "" "%~dp0InmarScope.exe"
RUNEOF

if [[ -f "$SRC/WINDOWS_BUILDER_V7B_CALL_HUNTER_BUILD_FIX.txt" ]]; then
  cp -f "$SRC/WINDOWS_BUILDER_V7B_CALL_HUNTER_BUILD_FIX.txt" "$RELEASE/" || true
fi

cat > "$RELEASE/README_WINDOWS.txt" <<'READMEEOF'
InmarScope Windows Build - V7B Call Hunter Build Fix
===============================================

Run:
  Run_InmarScope.bat

Main executable:
  InmarScope.exe

Notes:
- This app is built from SarahRoseLives/InmarScope.
- This builder performs a clean clone every time to avoid stale empty third_party folders.
- V7 adds a conservative Call Hunters safe-mode patch intended to reduce Windows UI stalls/freezes.
- It verifies and force-downloads missing libacars, Dear ImGui docking branch, and ImPlot sources before CMake starts.
- The WebView2Loader.dll warning during CMake is usually harmless because the vendored WebView2 DLL is copied after build.
- RTL-SDR and HackRF support require the proper Windows USB driver setup.
- For RTL-SDR / HackRF devices, use Zadig if Windows has assigned the wrong driver.
- Keep the DLL files in this folder next to InmarScope.exe.
READMEEOF

log "Done"
echo "Release path: $RELEASE"
ls -la "$RELEASE"
