@echo off
rem ===========================================
rem setenv.bat - Generate config.env file
rem Usage:
rem   setenv.bat -h
rem   setenv.bat -a AGENT-KEY -e OTLP-GRPC-ENDPOINT -H OTLP-HTTP-ENDPOINT
rem ===========================================

setlocal

rem --------------------------
rem Check for help or no arguments
rem --------------------------
if "%~1"=="" goto show_help
if /i "%~1"=="-h" goto show_help
if /i "%~1"=="--help" goto show_help

rem --------------------------
rem Parse command line arguments
rem --------------------------
set "AGENT_KEY="
set "OTLP_GRPC="
set "OTLP_HTTP="

:parse_args
if "%~1"=="" goto args_done

if /i "%~1"=="-a" (
    set "AGENT_KEY=%~2"
    shift
) else if /i "%~1"=="-e" (
    set "OTLP_GRPC=%~2"
    shift
) else if /i "%~1"=="-H" (
    set "OTLP_HTTP=%~2"
    shift
) else (
    echo Unknown argument: %~1
    echo.
    goto show_help
)

shift
goto parse_args

:args_done

rem --------------------------
rem Validate required arguments
rem --------------------------
if "%AGENT_KEY%"=="" (
    echo ERROR: -a <agent-key> is required
    endlocal
    exit /b 1
)
if "%OTLP_GRPC%"=="" (
    echo ERROR: -e <otlp-grpc-endpoint> is required
    endlocal
    exit /b 1
)
if "%OTLP_HTTP%"=="" (
    echo ERROR: -H <otlp-http-endpoint> is required
    endlocal
    exit /b 1
)

rem --------------------------
rem Add https:// prefix if no protocol exists
rem --------------------------
echo "%OTLP_HTTP%" | findstr /i /b /c:"http://" /c:"https://" >nul
if errorlevel 1 set "OTLP_HTTP=https://%OTLP_HTTP%"

for %%i in ("%~dp0..") do set "BASE_DIR=%%~fi"
for /f "usebackq delims=" %%i in ("%BASE_DIR%\VERSION") do set "VERSION=%%i"

rem --------------------------
rem Generate config.env
rem --------------------------
set "CONFIG_FILE=%BASE_DIR%\config\config.env"

(
echo INSTANA_OTEL_SERVICE_VERSION=%VERSION%
echo INSTANA_OTEL_ENDPOINT_GRPC=%OTLP_GRPC%
echo INSTANA_OTEL_ENDPOINT_HTTP=%OTLP_HTTP%
echo INSTANA_METRICS_ENDPOINT=
echo INSTANA_OPAMP_ENDPOINT=
echo INSTANA_COMM_PROVIDER=instana
echo INSTANA_KEY=%AGENT_KEY%
echo HOSTNAME=%COMPUTERNAME%
echo INSTANA_OTEL_LOG_LEVEL=info
) > "%CONFIG_FILE%"

echo Config file generated: %CONFIG_FILE%
echo The collector is installed in %BASE_DIR%
echo.

endlocal
exit /b 0

:show_help
echo.
echo Usage:
echo   setenv.bat -a ^<agent-key^> -e ^<otlp-grpc-endpoint^> -H ^<otlp-http-endpoint^>
echo.
echo Options:
echo   -a ^<agent-key^>             Instana agent key  (required)
echo   -e ^<otlp-grpc-endpoint^>    OTLP gRPC endpoint (required)
echo   -H ^<otlp-http-endpoint^>    OTLP HTTP endpoint (required)
echo   -h, --help                 Show this help message
echo.
endlocal
exit /b 1
