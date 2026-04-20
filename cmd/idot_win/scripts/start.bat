@echo off
setlocal

REM ===== Base directory (where this script is located) =====
for %%i in ("%~dp0..") do set "BASE_DIR=%%~fi"

REM ===== Configuration =====
set OTELCOL_EXE=instana-otelcol.exe
set CONFIG_FILE=%BASE_DIR%\config\config.yaml
set LOG_DIR=%BASE_DIR%\logs
set LOG_FILE=%LOG_DIR%\agent.log

REM ===== Create logs directory if it does not exist =====
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%"
)

REM ===== Check if Collector is already running =====
tasklist | findstr /i "%OTELCOL_EXE%" >nul
if %errorlevel%==0 (
    echo OpenTelemetry Collector is already running.
    goto :eof
)

REM ===== Start Collector in background =====
echo Starting OpenTelemetry Collector...
for /f "usebackq eol=# delims=" %%i in ("%BASE_DIR%\config\config.env") do set "%%i"
start "otelcol" /B cmd /c ""%BASE_DIR%\bin\%OTELCOL_EXE%" --config "%CONFIG_FILE%" > "%LOG_FILE%" 2>&1"

echo OpenTelemetry Collector started successfully.
endlocal
