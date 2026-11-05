$ErrorActionPreference = "Stop"
$sdkPath = "C:\Users\Harry\AppData\Local\Android\Sdk"
$cmdlineToolsPath = "$sdkPath\cmdline-tools"

Write-Host "Creating cmdline-tools directory..."
if (-not (Test-Path $cmdlineToolsPath)) {
    New-Item -ItemType Directory -Force -Path $cmdlineToolsPath | Out-Null
}

$zipPath = "$cmdlineToolsPath\cmdline-tools.zip"
Write-Host "Downloading cmdline-tools..."
# 11076708 is commandlinetools-win version 11.0
Invoke-WebRequest -Uri "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip" -OutFile $zipPath

Write-Host "Extracting cmdline-tools..."
if (Test-Path "$cmdlineToolsPath\temp") {
    Remove-Item -Recurse -Force "$cmdlineToolsPath\temp"
}
Expand-Archive -Path $zipPath -DestinationPath "$cmdlineToolsPath\temp" -Force

Write-Host "Moving to latest..."
if (Test-Path "$cmdlineToolsPath\latest") {
    Remove-Item -Recurse -Force "$cmdlineToolsPath\latest"
}
Rename-Item -Path "$cmdlineToolsPath\temp\cmdline-tools" -NewName "latest"
Move-Item -Path "$cmdlineToolsPath\temp\latest" -Destination $cmdlineToolsPath -Force
Remove-Item -Recurse -Force "$cmdlineToolsPath\temp"
Remove-Item -Force $zipPath

Write-Host "Accepting licenses..."
$sdkmanager = "$cmdlineToolsPath\latest\bin\sdkmanager.bat"
cmd.exe /c "echo y | `"$sdkmanager`" --licenses"

Write-Host "Installing NDK 27.0.12077973..."
& $sdkmanager "ndk;27.0.12077973"

Write-Host "Done!"
