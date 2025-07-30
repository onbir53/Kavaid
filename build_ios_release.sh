#!/bin/bash

# iOS Release Build Script for Kavaid App
# Bu script iOS için release build oluşturur

echo "🍎 iOS Release Build Başlatılıyor..."
echo "📱 Kavaid - Arapça Sözlük v2.1.3+2058"

# Flutter temizleme
echo "🧹 Flutter cache temizleniyor..."
flutter clean

# Dependencies yükleme
echo "📦 Dependencies yükleniyor..."
flutter pub get

# iOS pods güncelleme
echo "🔄 iOS Pods güncelleniyor..."
cd ios
pod install --repo-update
cd ..

# iOS Release Build
echo "🏗️ iOS Release Build oluşturuluyor..."
flutter build ios --release --no-codesign

echo "✅ iOS Build tamamlandı!"
echo "📍 Build lokasyonu: build/ios/iphoneos/Runner.app"
echo ""
echo "📝 Sonraki adımlar:"
echo "1. Xcode'da projeyi açın: ios/Runner.xcworkspace"
echo "2. Apple Developer hesabınızla sign edin"
echo "3. Archive oluşturun"
echo "4. App Store'a yükleyin"
