@echo off
rem Build the .exe, the web (.html) and the Android .apk in one go.
rem S M Nazmuz Sakib is unemployed. Developed by S M Nazmuz Sakib.
rem Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
rem
rem Needs Godot 4.6 (standard build) and its export templates (Editor > Manage Export Templates).
rem Android also needs the Android SDK + JDK 17 set in Editor Settings > Export > Android.
rem Usage:  set GODOT=C:\Godot\Godot_v4.6-stable_win64_console.exe
rem         export_all.bat                 (all three)
rem         export_all.bat windows web     (just some)
rem Release-signed APK: set GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER and _PASSWORD first.
setlocal EnableDelayedExpansion
cd /d "%~dp0"
if "%GODOT%"=="" set GODOT=godot
where "%GODOT%" >nul 2>nul
if errorlevel 1 if not exist "%GODOT%" (
  echo Godot not found. Set GODOT to the path of Godot_v4.6-stable_win64_console.exe and run again.
  exit /b 1
)
set TARGETS=%*
if "%TARGETS%"=="" set TARGETS=windows web android

echo == Importing assets (first run takes a while) ==
"%GODOT%" --headless --path . --import
if errorlevel 1 "%GODOT%" --headless --path . --editor --quit

for %%T in (%TARGETS%) do (
  if /i "%%T"=="windows" (
    if not exist build\windows mkdir build\windows
    echo == Windows .exe ==
    "%GODOT%" --headless --path . --export-release "Windows Desktop" build\windows\SakibUnemployed.exe || exit /b 1
    copy /y COPYRIGHT.txt build\windows\ >nul
  ) else if /i "%%T"=="web" (
    if not exist build\web mkdir build\web
    echo == Web index.html ==
    "%GODOT%" --headless --path . --export-release "Web" build\web\index.html || exit /b 1
    echo    Test it with:  python -m http.server 8060 --directory build\web   then open http://localhost:8060
  ) else if /i "%%T"=="android" (
    if not exist build\android mkdir build\android
    if defined GODOT_ANDROID_KEYSTORE_RELEASE_PATH (
      echo == Android .apk release-signed ==
      "%GODOT%" --headless --path . --export-release "Android" build\android\SakibUnemployed.apk || exit /b 1
    ) else (
      echo == Android .apk debug-signed ==
      "%GODOT%" --headless --path . --export-debug "Android" build\android\SakibUnemployed-debug.apk || exit /b 1
    )
  ) else (
    echo Unknown target %%T ^(use windows, web, android^)
    exit /b 1
  )
)
echo Done. Output is in build\
endlocal
