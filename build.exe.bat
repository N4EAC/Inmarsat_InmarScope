@echo off
setlocal EnableExtensions

title InmarScope Windows EXE Builder
cd /d "%~dp0"

echo ============================================================
echo  InmarScope Windows EXE Builder - V6 Cyberpunk UI + Layout Fix
echo ============================================================
echo.
echo This builder uses MSYS2 MinGW64, CMake and Ninja.
echo It performs a clean source clone and verifies missing third_party code
echo before CMake starts: libacars, Dear ImGui docking branch and ImPlot.
echo.
echo Finished app will be placed in: .\release\
echo.

set "MSYS_BASH=C:\msys64\usr\bin\bash.exe"
if not exist "%MSYS_BASH%" (
    echo ERROR: MSYS2 was not found at C:\msys64.
    echo.
    echo Install MSYS2 first from:
    echo   https://www.msys2.org/
    echo.
    echo Then run this file again.
    pause
    exit /b 1
)

set "PKG_ROOT=%CD%"
set "MSYSTEM=MINGW64"
set "CHERE_INVOKING=1"

"%MSYS_BASH%" -lc "cd \"$(cygpath -u '%PKG_ROOT%')\" && bash ./tools/windows_build/build_msys2.sh"
set "ERR=%ERRORLEVEL%"

echo.
if "%ERR%"=="0" (
    echo Build completed successfully.
    echo Your app should be in: %PKG_ROOT%\release\
) else (
    echo Build failed with exit code %ERR%.
    echo Check the output above for the first error.
)
echo.
pause
exit /b %ERR%
