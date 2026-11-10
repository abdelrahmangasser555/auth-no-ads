@echo off
title Auth No Ads tests
cd /d "%~dp0"
set "PATH=C:\Users\PC\dev\flutter\bin;C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot\bin;%PATH%"
set "ANDROID_HOME=C:\Users\PC\dev\android-sdk"
set "ANDROID_SDK_ROOT=C:\Users\PC\dev\android-sdk"
echo.
echo  Running Auth No Ads tests...
echo.
flutter test
echo.
pause
