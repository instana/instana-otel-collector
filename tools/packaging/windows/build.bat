@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::
:: Prerequisites (must be installed before running):
::   1. Go 1.21+          https://go.dev/dl/
::   2. WiX Toolset 3.11  https://wixtoolset.org/releases/
::      OR WiX 4.0        https://github.com/wixtoolset/wix4/releases
::   3. wget / curl       (for downloading WinSW, included in Windows 10+)
::
:: Usage:
::   build.bat <version>
::   Example: build.bat 1.316.0
:: ============================================================

if "%~1"=="" (
    echo ERROR: Version is required.
    echo Usage: build.bat ^<version^>
    echo Example: build.bat 1.316.0
    exit /b 1
)

set VERSION=%~1
set ROOT_DIR=%~dp0..\..\..
set SCRIPT_DIR=%~dp0
set INSTALLER_DIR=%SCRIPT_DIR%idot-windows-installer
set STAGING_DIR=%ROOT_DIR%\dist\staging
set OUTPUT_DIR=%ROOT_DIR%\dist

:: Compute MSI-compatible version (major.0.minor) because MSI requires minor < 256
:: e.g. 1.316.0 -> 1.0.316
for /f "tokens=1,2 delims=." %%a in ("%VERSION%") do (
    set MSI_MAJOR=%%a
    set MSI_MINOR=%%b
)
set MSI_VERSION=%MSI_MAJOR%.0.%MSI_MINOR%

echo ============================================================
echo  Building Instana OTel Collector MSI v%VERSION%
echo ============================================================

:: ------------------------------------------------------------
:: Step 1: Build the collector binary
:: ------------------------------------------------------------
echo.
echo [1/5] Building collector binary...

cd /d "%ROOT_DIR%\cmd\idot_win"
if errorlevel 1 goto :error

set GOOS=windows
set GOARCH=amd64
set CGO_ENABLED=0

go build -trimpath -o instana-otelcol.exe -ldflags="-s -w"
if errorlevel 1 (
    echo ERROR: Go build failed.
    goto :error
)
echo   OK: instana-otelcol.exe built

cd /d "%ROOT_DIR%"

:: ------------------------------------------------------------
:: Step 2: Create staging directory structure
:: ------------------------------------------------------------
echo.
echo [2/5] Creating staging directory...

if exist "%STAGING_DIR%" rmdir /s /q "%STAGING_DIR%"
mkdir "%STAGING_DIR%\bin"
mkdir "%STAGING_DIR%\config"
mkdir "%STAGING_DIR%\logs"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
echo   OK: Staging directory created at %STAGING_DIR%

:: ------------------------------------------------------------
:: Step 3: Copy files into staging
:: ------------------------------------------------------------
echo.
echo [3/5] Copying files to staging...

copy /y "%ROOT_DIR%\cmd\idot_win\instana-otelcol.exe" "%STAGING_DIR%\bin\instana-otelcol.exe"
if errorlevel 1 ( echo ERROR: Failed to copy binary & goto :error )
echo   OK: instana-otelcol.exe

copy /y "%ROOT_DIR%\config\windows\config.yaml" "%STAGING_DIR%\config\config.yaml"
if errorlevel 1 ( echo ERROR: Failed to copy config.yaml & goto :error )
echo   OK: config.yaml

echo %VERSION%> "%STAGING_DIR%\VERSION"
echo   OK: VERSION file

:: ------------------------------------------------------------
:: Step 4: Build MSI with WiX
:: ------------------------------------------------------------
echo.
echo [4/5] Building MSI with WiX...

:: Try WiX 4.0 first
where wix >nul 2>&1
if %errorlevel% equ 0 (
    echo   Using WiX 4.0...
    wix extension add WixToolset.UI.wixext 2>nul
    wix extension add WixToolset.Util.wixext 2>nul
    wix build ^
        -d Version=%VERSION% ^
        -d MsiVersion=%MSI_VERSION% ^
        -d SourceDir="%STAGING_DIR%" ^
        -ext WixToolset.UI.wixext ^
        -ext WixToolset.Util.wixext ^
        -culture en-US ^
        -loc "%INSTALLER_DIR%\en-US.wxl" ^
        -out "%OUTPUT_DIR%\instana-otel-collector-%VERSION%.msi" ^
        "%INSTALLER_DIR%\InstanaIdot.wxs" ^
        "%INSTALLER_DIR%\InstanaIdotUI.wxs"
    if errorlevel 1 ( echo ERROR: WiX build failed & goto :error )
    goto :checksum
)

:: Fall back to WiX 3.x
if "%WIX%"=="" (
    echo ERROR: WiX Toolset not found.
    echo   Install WiX 4.0: https://github.com/wixtoolset/wix4/releases
    echo   Or WiX 3.11:     https://wixtoolset.org/releases/
    goto :error
)

echo   Using WiX 3.x from %WIX%...
set WIX_BIN=%WIX%\bin
set FILES_WXS=%INSTALLER_DIR%\Files.wxs
set WIXOBJ_DIR=%OUTPUT_DIR%\wixobj
if not exist "%WIXOBJ_DIR%" mkdir "%WIXOBJ_DIR%"

"%WIX_BIN%\heat.exe" dir "%STAGING_DIR%" ^
    -cg InstanaCollectorFiles ^
    -dr INSTALLFOLDER ^
    -platform x64 ^
    -gg -sfrag -srd -sreg ^
    -out "%FILES_WXS%"
if errorlevel 1 ( echo ERROR: heat.exe failed & goto :error )

:: Remove files explicitly defined in InstanaIdot.wxs to avoid duplicate component errors
:: instana-otelcol.exe: KeyPath for service component (must be declared there for correct ImagePath)
:: config.yaml: declared as CollectorConfig in InstanaIdot.wxs
powershell -NoProfile -Command ^
    "(Get-Content '%FILES_WXS%') | Where-Object { $_ -notmatch 'instana-otelcol\.exe' -and $_ -notmatch 'config\.yaml' } | Set-Content '%FILES_WXS%'"
if errorlevel 1 ( echo ERROR: Failed to post-process Files.wxs & goto :error )

"%WIX_BIN%\candle.exe" "%INSTALLER_DIR%\InstanaIdot.wxs" ^
    "-dVersion=%VERSION%" "-dMsiVersion=%MSI_VERSION%" "-dSourceDir=%STAGING_DIR%" ^
    -out "%WIXOBJ_DIR%\InstanaIdot.wixobj" ^
    -ext WixUIExtension -ext WixUtilExtension
if errorlevel 1 ( echo ERROR: candle.exe failed on InstanaIdot.wxs & goto :error )

if exist "%INSTALLER_DIR%\InstanaIdotUI.wxs" (
    "%WIX_BIN%\candle.exe" "%INSTALLER_DIR%\InstanaIdotUI.wxs" ^
        "-dVersion=%VERSION%" "-dMsiVersion=%MSI_VERSION%" "-dSourceDir=%STAGING_DIR%" ^
        -out "%WIXOBJ_DIR%\InstanaIdotUI.wixobj" ^
        -ext WixUIExtension -ext WixUtilExtension
    if errorlevel 1 ( echo ERROR: candle.exe failed on InstanaIdotUI.wxs & goto :error )
)

"%WIX_BIN%\candle.exe" "%FILES_WXS%" ^
    "-dVersion=%VERSION%" "-dMsiVersion=%MSI_VERSION%" "-dSourceDir=%STAGING_DIR%" ^
    -out "%WIXOBJ_DIR%\Files.wixobj" ^
    -ext WixUIExtension -ext WixUtilExtension
if errorlevel 1 ( echo ERROR: candle.exe failed on Files.wxs & goto :error )

"%WIX_BIN%\light.exe" "%WIXOBJ_DIR%\*.wixobj" ^
    -out "%OUTPUT_DIR%\instana-otel-collector-%VERSION%.msi" ^
    -b "%STAGING_DIR%" ^
    -b "%INSTALLER_DIR%" ^
    -ext WixUIExtension -ext WixUtilExtension ^
    -cultures:en-US ^
    -loc "%INSTALLER_DIR%\en-US.wxl" ^
    -sice:ICE03 -sice:ICE18 -sice:ICE61 -sice:ICE80
if errorlevel 1 ( echo ERROR: light.exe failed & goto :error )

:: Cleanup WiX temp files
del /q "%FILES_WXS%" 2>nul
rmdir /s /q "%WIXOBJ_DIR%" 2>nul

:checksum
:: ------------------------------------------------------------
:: Step 5: Generate SHA256 checksum
:: ------------------------------------------------------------
echo.
echo [5/5] Generating checksum...

set MSI_FILE=%OUTPUT_DIR%\instana-otel-collector-%VERSION%.msi
powershell -NoProfile -Command ^
    "$h = (Get-FileHash '%MSI_FILE%' -Algorithm SHA256).Hash.ToLower(); " ^
    "$h + '  instana-otel-collector-%VERSION%.msi' | Set-Content '%MSI_FILE%.sha256'"
if errorlevel 1 ( echo WARNING: Checksum generation failed ) else ( echo   OK: checksum generated )

echo.
echo ============================================================
echo  Build complete!
echo  MSI:      %OUTPUT_DIR%\instana-otel-collector-%VERSION%.msi
echo  Checksum: %OUTPUT_DIR%\instana-otel-collector-%VERSION%.msi.sha256
echo ============================================================
exit /b 0

:error
echo.
echo Build failed. See errors above.
exit /b 1