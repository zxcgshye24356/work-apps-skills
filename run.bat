@echo off
setlocal

REM Prefer WorkBuddy managed Python, fall back to system python on PATH.
set "PY=C:\Users\liu\.workbuddy\binaries\python\versions\3.13.12\python.exe"
if not exist "%PY%" (
    for /f "delims=" %%i in ('where python 2^>nul') do (
        set "PY=%%i"
        goto :found_py
    )
)

:found_py
if not exist "%PY%" (
    echo ERROR: Python not found.
    echo Tried: C:\Users\liu\.workbuddy\binaries\python\versions\3.13.12\python.exe
    echo Also tried: python on PATH
    echo.
    echo Please install Python or add it to PATH.
    pause
    exit /b 1
)

cd /d "%~dp0"

echo Using Python: %PY%

if not exist "venv" (
    echo First run: creating environment and installing dependencies (this may take a few minutes)...
    "%PY%" -m venv venv
    call venv\Scripts\activate.bat
    python -m pip install -r requirements.txt
    python -m playwright install chromium
) else (
    call venv\Scripts\activate.bat
)

echo Starting app, browser will open at http://localhost:8501 ...
python -m streamlit run app.py

pause
