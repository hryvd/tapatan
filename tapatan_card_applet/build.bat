@echo off
setlocal
echo ========================================================
echo Compiling TapatMFAApplet for JCOP4 J3R150 Java Card...
echo ========================================================

set "APPLET_ROOT=%~dp0"
set "THESIS_ROOT=%APPLET_ROOT%.."
set "SDK_ROOT=%THESIS_ROOT%\scratch\sdks\jc305u3_kit"

if not defined JAVA_HOME (
    set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.19.10-hotspot"
)

if not exist "%JAVA_HOME%\bin\javac.exe" (
    echo [ERROR] JDK not found at %JAVA_HOME%. Please set JAVA_HOME.
    exit /b 1
)

if not exist "%APPLET_ROOT%bin" mkdir "%APPLET_ROOT%bin"
if not exist "%APPLET_ROOT%deliverables" mkdir "%APPLET_ROOT%deliverables"

echo [1/2] Compiling Java Card source to bytecode...
"%JAVA_HOME%\bin\javac" -source 7 -target 7 -cp "%SDK_ROOT%\lib\api_classic.jar" -d "%APPLET_ROOT%bin" "%APPLET_ROOT%src\com\tapatan\card\TapatMFAApplet.java"
if %errorlevel% neq 0 (
    echo [ERROR] Compilation failed.
    exit /b %errorlevel%
)

echo [2/2] Converting bytecode to Java Card CAP file...
cmd.exe /c ""%SDK_ROOT%\bin\converter.bat" -classdir "%APPLET_ROOT%bin" -exportpath "%SDK_ROOT%\api_export_files" -applet 0xF0:0x74:0x61:0x70:0x61:0x74:0x61:0x6E:0x01:0x01 com.tapatan.card.TapatMFAApplet -d "%APPLET_ROOT%deliverables" -out CAP EXP JCA com.tapatan.card 0xF0:0x74:0x61:0x70:0x61:0x74:0x61:0x6E 1.0"
if %errorlevel% neq 0 (
    echo [ERROR] Conversion failed.
    exit /b %errorlevel%
)

copy /y "%APPLET_ROOT%deliverables\com\tapatan\card\javacard\card.cap" "%APPLET_ROOT%deliverables\TapatMFAApplet.cap" >nul

echo ========================================================
echo BUILD SUCCESSFUL!
echo Output: %APPLET_ROOT%deliverables\TapatMFAApplet.cap
echo ========================================================
