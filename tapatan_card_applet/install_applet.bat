@echo off
setlocal
echo ========================================================
echo Installing TapatMFAApplet onto JCOP4 J3R150 Card...
echo ========================================================

set "APPLET_ROOT=%~dp0"
set "THESIS_ROOT=%APPLET_ROOT%.."
set "GP_JAR=%THESIS_ROOT%\scratch\gp.jar"
set "CAP_FILE=%APPLET_ROOT%deliverables\TapatMFAApplet.cap"

if not defined JAVA_HOME (
    set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"
)

if not exist "%CAP_FILE%" (
    echo [ERROR] CAP file not found! Please run build.bat first.
    exit /b 1
)

if not exist "%GP_JAR%" (
    echo [ERROR] gp.jar not found at %GP_JAR%.
    exit /b 1
)

pushd "%THESIS_ROOT%"
"%JAVA_HOME%\bin\java" --add-modules java.smartcardio -cp "%GP_JAR%" scratch\upload_applet.java
set "ERR=%errorlevel%"
popd

if %ERR% neq 0 (
    echo [ERROR] Applet installation failed.
    exit /b %ERR%
)

echo ========================================================
echo INSTALLATION SUCCESSFUL!
echo ========================================================
