@echo off
echo ==========================================
echo Crystal Heikin Ashi - Flask Bridge
echo ==========================================
echo.

REM Vérifier Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Python n'est pas installé ou pas dans le PATH
    pause
    exit /b 1
)

REM Installer les dépendances si nécessaire
if not exist "venv" (
    echo Creation de l'environnement virtuel...
    python -m venv venv
    call venv\Scripts\activate
    pip install -r requirements.txt
) else (
    call venv\Scripts\activate
)

echo.
echo Demarrage du serveur...
echo Dashboard: http://localhost:5000
echo.
python app.py

pause
