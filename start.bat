@echo off
setlocal
cd /d "%~dp0"
if not exist "venv" (
    echo venv not found. Please run install first:
    echo python -m venv venv
    echo venv\Scripts\activate.bat
    echo python -m pip install -r requirements.txt
    echo python -m playwright install chromium
    pause
    exit /b 1
)
call venv\Scripts\activate.bat
python -m streamlit run app.py
pause
