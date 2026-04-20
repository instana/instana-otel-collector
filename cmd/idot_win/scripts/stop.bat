@echo off
setlocal

REM ===== Configuration =====
set OTELCOL_EXE=instana-otelcol.exe

REM ===== Check if Collector is running =====
tasklist | findstr /i "%OTELCOL_EXE%" >nul
if %errorlevel% neq 0 (
    echo OpenTelemetry Collector is not running.
    goto :eof
)

REM ===== Force stop the Collector process =====
echo Stopping OpenTelemetry Collector...
taskkill /F /IM "%OTELCOL_EXE%" >nul

echo OpenTelemetry Collector stopped successfully.
endlocal
