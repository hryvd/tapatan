@echo off
setlocal
echo ========================================================
echo Installing TapatMFAApplet onto JCOP4 J3R150 Card...
echo ========================================================

set "APPLET_ROOT=%~dp0"
set "THESIS_ROOT=%APPLET_ROOT%.."
set "GP_JAR=%THESIS_ROOT%\scratch\gp.jar"
set "CAP_FILE=%APPLET_ROOT%deliverables\TapatMFAApplet.cap"

if not exist "%CAP_FILE%" (
    echo [ERROR] CAP file not found! Please run build.bat first.
    exit /b 1
)

if not exist "%GP_JAR%" (
    echo [ERROR] gp.jar not found at %GP_JAR%.
    exit /b 1
)

echo [1/2] Connecting to card and installing applet...
java -jar "%GP_JAR%" --key-enc 90379A3E7116D455E55F9398736A01CA --key-mac 473F36161A7F7F60CC3A766EA4BE5247 --key-dek D3749ED4FF42FD58B39EEB562B017CD9 --install "%CAP_FILE%" --default-contactless -v
if %errorlevel% neq 0 (
    echo [ERROR] Applet installation failed.
    exit /b %errorlevel%
)

echo [2/2] Verifying applet on card...
java -jar "%GP_JAR%" --key-enc 90379A3E7116D455E55F9398736A01CA --key-mac 473F36161A7F7F60CC3A766EA4BE5247 --key-dek D3749ED4FF42FD58B39EEB562B017CD9 -l

echo ========================================================
echo INSTALLATION SUCCESSFUL!
echo Now run: java tapatan_card_applet/test_applet_pcsc.java to personalize your virtual card credentials!
echo ========================================================
