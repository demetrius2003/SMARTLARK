@echo off
echo Compiling SMARTLARK...
dcc32 SMARTLARK.dpr
if %ERRORLEVEL% EQU 0 (
    echo Compilation successful!
) else (
    echo Compilation failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

