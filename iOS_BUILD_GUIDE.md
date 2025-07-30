# iOS Build Rehberi - Kavaid Uygulaması

## ✅ Tamamlanan Düzeltmeler

### 1. AppDelegate.swift Güncellemeleri
- ✅ Firebase.configure() eklendi
- ✅ GADMobileAds.sharedInstance().start() eklendi
- ✅ Gerekli import'lar eklendi (Firebase, GoogleMobileAds)

### 2. Info.plist Güncellemeleri
- ✅ NSMicrophoneUsageDescription eklendi (TTS için)
- ✅ NSUserTrackingUsageDescription eklendi (iOS 14+ reklam takibi)
- ✅ GADApplicationIdentifier eklendi (AdMob App ID)
- ✅ NSAppTransportSecurity ayarları eklendi (Firebase/Google API'ler için)

### 3. Podfile Optimizasyonları
- ✅ iOS 15.0+ deployment target zorlandı
- ✅ Firebase ve AdMob için gerekli build ayarları eklendi
- ✅ Permission preprocessor definitions eklendi
- ✅ Bitcode devre dışı bırakıldı (Firebase uyumluluğu için)

### 4. Build Scriptleri Oluşturuldu
- ✅ build_ios_release.sh (Bash script)
- ✅ build_ios_debug.sh (Debug için)
- ✅ build_ios_release.ps1 (PowerShell script)

## 🚀 iOS Build Adımları

### Adım 1: Dependencies Güncelleme
```bash
flutter clean
flutter pub get
cd ios
pod install --repo-update
cd ..
```

### Adım 2: iOS Build
```bash
# Release build için
flutter build ios --release --no-codesign

# Debug build için (Simulator)
flutter run -d ios
```

### Adım 3: Xcode'da Signing
1. `ios/Runner.xcworkspace` dosyasını Xcode'da açın
2. Runner target'ını seçin
3. Signing & Capabilities sekmesinde:
   - Team'inizi seçin
   - Bundle Identifier'ı kontrol edin: `com.onbir.kavaid`
4. Archive oluşturun (Product → Archive)

## ⚠️ Önemli Notlar

### AdMob App ID
- Şu anda test AdMob ID kullanılıyor: `ca-app-pub-3940256099942544~1458002511`
- **ÜRETİM İÇİN:** Gerçek AdMob App ID'nizi Info.plist'te güncelleyin

### Firebase Configuration
- GoogleService-Info.plist dosyası mevcut ve doğru
- Bundle ID tutarlı: `com.onbir.kavaid`

### iOS Permissions
- Mikrofon: TTS (Text-to-Speech) için gerekli
- Fotoğraf Kütüphanesi: Kelime kartı paylaşımı için
- Tracking: Reklam kişiselleştirmesi için (iOS 14+)

## 🔧 Sorun Giderme

### Pod Install Hatası
```bash
cd ios
pod deintegrate
pod install --repo-update
```

### Build Hatası
```bash
flutter clean
flutter pub get
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..
flutter build ios --release --no-codesign
```

### Xcode Signing Hatası
1. Apple Developer hesabınızın aktif olduğundan emin olun
2. Bundle ID'nin benzersiz olduğundan emin olun
3. Provisioning Profile'ın güncel olduğundan emin olun

## 📱 Test Etme

### iOS Simulator'da Test
```bash
flutter run -d ios
```

### Fiziksel Cihazda Test
1. Cihazı USB ile bağlayın
2. Xcode'da cihazı seçin
3. Run butonuna basın

## 🎯 App Store Yayınlama

1. Archive oluşturun (Xcode)
2. Organizer'da "Distribute App" seçin
3. App Store Connect'e yükleyin
4. TestFlight'ta test edin
5. App Store Review'a gönderin

## ✅ Kontrol Listesi

- [ ] Firebase çalışıyor mu?
- [ ] AdMob reklamları görünüyor mu?
- [ ] TTS (Arapça telaffuz) çalışıyor mu?
- [ ] In-App Purchase çalışıyor mu?
- [ ] Kelime kartı paylaşımı çalışıyor mu?
- [ ] Uygulama değerlendirmesi çalışıyor mu?
- [ ] İnternet bağlantısı kontrolü çalışıyor mu?
