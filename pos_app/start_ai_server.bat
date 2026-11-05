@echo off
echo ============================================================
echo  Sar-E AI Product Recognition Server
echo ============================================================
echo.
echo Checking Python dependencies...
pip install fastapi uvicorn torch torchvision pillow --quiet
echo.
echo Starting API server on http://localhost:8000
echo Flutter app uses http://10.0.2.2:8000 (Android emulator)
echo For physical device, update baseUrl in ai_scan_service.dart
echo.
python api.py
pause
