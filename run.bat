@echo off
REM ============================================
REM Flutter Runner Wrapper - Windows
REM Menyaring peringatan KGP dari output terminal
REM ============================================
REM Usage: run.bat <flutter-command> [arguments]
REM Example: run.bat run
REM Example: run.bat build apk
REM ============================================

if "%1"=="" (
    echo Usage: run.bat ^<flutter-command^> [arguments]
    echo.
    echo Examples:
    echo   run.bat run
    echo   run.bat build apk --debug
    echo   run.bat clean
    goto :eof
)

flutter %* 2>&1 | findstr /v "Kotlin Gradle Plugin (KGP)|Future versions of Flutter"
exit /b 0
