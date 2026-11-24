@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

cd /d "%~dp0"
echo ======================================================
echo    LEMINHTTS ADMIN - CONG CU DONG GOI APK
echo ======================================================
echo.

:: Tim flutter
set "FLUTTER_CMD=flutter"
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "C:\flutter\bin\flutter.bat" (
        set "FLUTTER_CMD=C:\flutter\bin\flutter.bat"
    ) else (
        echo [LOI] Khong tim thay Flutter SDK! Vui long kiem tra PATH hoac C:\flutter\bin\flutter.bat
        pause
        exit /b 1
    )
)

:: Doc version tu pubspec.yaml
for /f "tokens=2 delims=: " %%a in ('findstr /r "^version:" pubspec.yaml') do (
    set "FULL_VER=%%a"
)

:: Tach phan version truoc dau + (vi du: 1.0.2 tu 1.0.2+3)
for /f "tokens=1 delims=+" %%v in ("!FULL_VER!") do (
    set "APP_VER=%%v"
)

echo [*] Phien ban hien tai: V!APP_VER! (Build !FULL_VER!)
echo [*] Dang bien dich Release APK bang Flutter...
echo.

call %FLUTTER_CMD% build apk --release
if %ERRORLEVEL% neq 0 (
    echo.
    echo [LOI] Bien dich APK that bai!
    pause
    exit /b %ERRORLEVEL%
)

set "SOURCE_APK=build\app\outputs\flutter-apk\app-release.apk"
set "OUT_NAME=LeMinhTTS_Admin V!APP_VER!.apk"
set "DEST_DIR=..\LeMinhTTS_Filecaidat"

echo.
echo [*] Dang sao chep file APK kem version...
copy /y "!SOURCE_APK!" "!OUT_NAME!" >nul
copy /y "!SOURCE_APK!" "LeMinhTTS_Admin.apk" >nul

if exist "!DEST_DIR!" (
    copy /y "!SOURCE_APK!" "!DEST_DIR!\!OUT_NAME!" >nul
    copy /y "!SOURCE_APK!" "!DEST_DIR!\LeMinhTTS_Admin.apk" >nul
)

echo.
echo ======================================================
echo  THANH CONG! File APK da duoc tao:
echo  - !OUT_NAME!
if exist "!DEST_DIR!" (
echo  - !DEST_DIR!\!OUT_NAME!
)
echo ======================================================
echo.
pause
