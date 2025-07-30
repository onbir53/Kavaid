# iOS Release Build Script for Kavaid App (PowerShell)
# Bu script iOS için release build oluşturur

Write-Host "🍎 iOS Release Build Başlatılıyor..." -ForegroundColor Green
Write-Host "📱 Kavaid - Arapça Sözlük v2.1.3+2058" -ForegroundColor Cyan

# Flutter temizleme
Write-Host "🧹 Flutter cache temizleniyor..." -ForegroundColor Yellow
flutter clean

# Dependencies yükleme
Write-Host "📦 Dependencies yükleniyor..." -ForegroundColor Yellow
flutter pub get

# iOS pods güncelleme
Write-Host "🔄 iOS Pods güncelleniyor..." -ForegroundColor Yellow
Set-Location ios
pod install --repo-update
Set-Location ..

# iOS Release Build
Write-Host "🏗️ iOS Release Build oluşturuluyor..." -ForegroundColor Yellow
flutter build ios --release --no-codesign

Write-Host "✅ iOS Build tamamlandı!" -ForegroundColor Green
Write-Host "📍 Build lokasyonu: build/ios/iphoneos/Runner.app" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 Sonraki adımlar:" -ForegroundColor Magenta
Write-Host "1. Xcode'da projeyi açın: ios/Runner.xcworkspace" -ForegroundColor White
Write-Host "2. Apple Developer hesabınızla sign edin" -ForegroundColor White
Write-Host "3. Archive oluşturun" -ForegroundColor White
Write-Host "4. App Store'a yükleyin" -ForegroundColor White
