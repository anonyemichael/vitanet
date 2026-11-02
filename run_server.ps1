Write-Host "Launching VitaNet on your normal browser (http://localhost:5000)..." -ForegroundColor Cyan
Start-Process "http://localhost:5000"
flutter run -d web-server --web-port 5000
