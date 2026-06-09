@echo off
REM Flutter App Bundle Fix - Quick Build Script for Windows PowerShell
REM Run this script to rebuild your app with the bundle fixes

echo ========================================
echo Flutter App Bundle Fix - Build Script
echo ========================================
echo.

echo [1/5] Cleaning Flutter cache...
flutter clean
if errorlevel 1 goto error

echo [2/5] Cleaning Gradle...
cd android
call gradlew clean
if errorlevel 1 goto error
cd ..

echo [3/5] Getting Flutter dependencies...
flutter pub get
if errorlevel 1 goto error

echo [4/5] Building Release APK (for testing)...
flutter build apk --release
if errorlevel 1 goto error

echo.
echo ========================================
echo APK built successfully!
echo Location: build\app\outputs\flutter-apk\app-release.apk
echo ========================================
echo.

echo [5/5] Building App Bundle (for Play Store)...
flutter build appbundle --release
if errorlevel 1 goto error

echo.
echo ========================================
echo Build Complete!
echo ========================================
echo APK: build\app\outputs\flutter-apk\app-release.apk
echo AAB: build\app\outputs\bundle\release\app-release.aab
echo.
echo Next Steps:
echo 1. Test APK on device first
echo 2. Upload AAB to Play Console
echo 3. Test in Internal Testing track first
echo 4. Check BUNDLE_FIX_GUIDE.md for detailed instructions
echo ========================================
echo.
pause

goto end

:error
echo.
echo ========================================
echo ERROR: Build failed!
echo ========================================
echo Please check the error messages above.
pause
exit /b 1

:end
exit /b 0

