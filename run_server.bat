@echo off
echo Launching VitaNet on your normal browser (http://localhost:5000)...
start http://localhost:5000
flutter run -d web-server --web-port 5000
