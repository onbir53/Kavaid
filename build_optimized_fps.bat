@echo off
echo.
echo ========================================
echo    KAVAID FPS OPTIMIZED BUILD
echo ========================================
echo.

echo 🚀 FPS Optimize Edilmiş APK Build Başlatılıyor...
echo.

echo 🔧 Flutter clean işlemi...
flutter clean

echo.
echo 📦 Pub get işlemi...
flutter pub get

echo.
echo 🛠️ JSON serialization build...
flutter packages pub run build_runner build --delete-conflicting-outputs

echo.
echo 🎯 FPS Optimize Edilmiş Release APK Build işlemi başlatılıyor...
echo.
echo 📱 Bu build şunlar için optimize edilmiştir:
echo    • 🚀 120Hz cihazlar için ultra performans
echo    • ⚡ 90Hz cihazlar için yüksek performans
echo    • 📱 60Hz cihazlar için stabil performans
echo    • 🧹 Memory optimizasyonları
echo    • 📊 Frame drop izleme
echo    • ⚡ GPU hızlandırma
echo.

flutter build apk --release --shrink --target-platform android-arm64 --analyze-size

echo.
echo 🏗️ APK dosyası oluşturuluyor...

set TIMESTAMP=%date:~-4,4%-%date:~-7,2%-%date:~-10,2%
set OUTPUT_NAME=kavaid-fps-optimized-%TIMESTAMP%.apk

echo.
echo 📦 APK dosyası yeniden adlandırılıyor...
copy "build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_NAME%"

echo.
echo ✅ FPS Optimize Edilmiş APK Hazır!
echo 📁 Dosya: %OUTPUT_NAME%
echo.
echo 🎮 Performans Özellikleri:
echo    • Otomatik yüksek refresh rate desteği (60/90/120Hz)
echo    • Adaptif animasyon süreleri
echo    • Optimize edilmiş cache ayarları
echo    • GPU donanım hızlandırma
echo    • Memory garbage collection optimizasyonu
echo    • Frame drop monitoring
echo    • RepaintBoundary optimizasyonları
echo.
echo 📊 Test için: test_fps_performance.bat çalıştırın
echo.
pause 