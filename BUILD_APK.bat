@echo off
title Auth No Ads APK
cd /d "%~dp0"
set "PATH=C:\Users\PC\dev\flutter\bin;C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot\bin;%PATH%"
set "ANDROID_HOME=C:\Users\PC\dev\android-sdk"
set "ANDROID_SDK_ROOT=C:\Users\PC\dev\android-sdk"
echo.
echo  Building AuthNoAds-install.apk ...
echo.
flutter build apk --release
if errorlevel 1 (
  echo Build failed.
  pause
  exit /b 1
)
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "AuthNoAds-install.apk"
echo.
echo  Done. Install file:
echo  %cd%\AuthNoAds-install.apk
echo.
pause
