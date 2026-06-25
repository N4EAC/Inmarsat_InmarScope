InmarScope Windows Builder Cyberpunk UI + Layout Fix
This downloads / clones the files created by Sarah in her repository
==================================================

1. Install MSYS2 if it is not already installed:
   https://www.msys2.org/

2. Extract this ZIP somewhere simple

3. Double-click:
   build.exe.bat

4. When successful, run:
   release\Run_InmarScope.bat
<img width="1920" height="1032" alt="image" src="https://github.com/user-attachments/assets/e835ce66-9331-4a0c-84f4-723287b5b8f6" />

What changed
---------------
This build keeps the original InmarScope UI, applies a Cyberpunk theme, and adds a small
layout fix for the Decoder panel where the Audio out / Refresh controls could
be clipped by the dock divider. It changes ImGui colors, borders, rounding,
buttons, tabs, tables, plots, scrollbars, docking preview, and panels to use:

- dark purple/black background
- neon purple/magenta borders and controls
- cyan highlights
- yellow active/alert accents
- slightly rounded futuristic panels

This is intentionally a small UI theme.

Dependency fixes
---------------------------------
The builder still performs a clean clone and verifies/repairs:

- third_party/libacars/CMakeLists.txt
- third_party/imgui/imgui.cpp
- Dear ImGui docking branch symbols
- third_party/implot/implot.cpp

About the WebView2 warning
--------------------------
This warning is usually not fatal:
  Runtime DLL not found: C:/msys64/mingw64/bin/WebView2Loader.dll

The builder copies WebView2Loader.dll from the vendored WebView2 SDK after the
build when available. If the app later complains about WebView2, install the
Microsoft Edge WebView2 Runtime.


UI layout fix
----------------
This version patches the real InmarScope UI source during build to reduce the
Audio out clipping seen in the Decoders panel:

- gives the left Control/Decoders dock slightly more initial width
- changes the Audio out combo to use a label above the control when matched
- keeps the audio Refresh button on the next line instead of squeezing it into
  the dock divider

If your saved ImGui layout still opens cramped, use View / Reset layout if the
app offers it, or delete the generated imgui.ini file next to the executable.

Note: This build adds a conservative safe-mode patch for Call Hunters performance stalls.

## <B>Credits: </B>

SarahRoseLives
Sarah Rose  · she/her AD8NT
Linux fan girl with a habit of making systems behave in ways they were never meant to.

Repo:
https://github.com/sarahroselives/inmarscope

Forum posts:
https://forums.radioreference.com/threads/inmarscope-multi-channel-inmarsat-decoder-for-windows.501470
