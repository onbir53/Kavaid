#!/bin/bash

# iOS Debug Build Script for Kavaid App
# Bu script iOS için debug build oluşturur ve simulator'da çalıştırır

echo "🍎 iOS Debug Build Başlatılıyor..."
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
pod install
cd ..

# iOS Simulator'da çalıştır
echo "🏗️ iOS Simulator'da çalıştırılıyor..."
flutter run -d ios

echo "✅ iOS Debug Build tamamlandı!"
