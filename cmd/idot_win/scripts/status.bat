@echo off
setlocal

REM ===== Configuration =====
set OTELCOL_EXE=instana-otelcol.exe

REM ===== Check process status =====
tasklist | findstr /i "%OTELCOL_EXE%" >nul
if %errorlevel%==0 (
    echo OpenTelemetry Collector status: RUNNING
) else (
    echo OpenTelemetry Collector status: STOPPED
)

endlocal
