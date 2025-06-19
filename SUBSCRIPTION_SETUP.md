# Kavaid - Abonelik Sistemi Kurulum Rehberi

## 📱 Aylık 60 TL Abonelik Sistemi

Bu rehber, Kavaid uygulamasında aylık 60 TL'lik abonelik sistemini kurmak için gerekli adımları açıklar.

## 🎯 Özellikler
- ✅ Aylık 60 TL abonelik
- ✅ Otomatik yenileme
- ✅ Sınırsız kelime erişimi
- ✅ Reklamsız kullanım
- ✅ iOS ve Android desteği

## 📋 Android Kurulum Adımları

### 1. Google Play Console'da Abonelik Oluşturma

1. [Google Play Console](https://play.google.com/console)'a gidin
2. Uygulamanızı seçin
3. Sol menüden **Monetize > Products > Subscriptions** seçin
4. **Create subscription** butonuna tıklayın
5. Aşağıdaki bilgileri girin:
   - **Product ID**: `kavaid_monthly_subscription`
   - **Name**: Kavaid Premium Aylık
   - **Description**: Sınırsız kelime erişimi ve reklamsız kullanım
   - **Default price**: 60 TRY

### 2. Android Manifest Güncelleme

`android/app/src/main/AndroidManifest.xml` dosyasına billing permission ekleyin:

```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

### 3. build.gradle Güncelleme

`android/app/build.gradle` dosyasında minSdkVersion'ı kontrol edin:

```gradle
android {
    defaultConfig {
        minSdkVersion 19 // veya daha yüksek
    }
}
```

## 📱 iOS Kurulum Adımları

### 1. App Store Connect'te Abonelik Oluşturma

1. [App Store Connect](https://appstoreconnect.apple.com)'e gidin
2. Uygulamanızı seçin
3. **Features > In-App Purchases** seçin
4. **Create** butonuna tıklayın
5. **Auto-Renewable Subscription** seçin
6. Aşağıdaki bilgileri girin:
   - **Reference Name**: Kavaid Premium Monthly
   - **Product ID**: `kavaid_monthly_subscription`
   - **Subscription Group**: Kavaid Premium

### 2. Abonelik Grubu Oluşturma

1. **Subscription Groups** bölümüne gidin
2. **Create Subscription Group** tıklayın
3. Group Name: `Kavaid Premium`
4. Subscription Duration: **1 Month**
5. Price: **60 TRY**

### 3. iOS Proje Ayarları

1. Xcode'da projenizi açın
2. **Signing & Capabilities** sekmesine gidin
3. **+ Capability** butonuna tıklayın
4. **In-App Purchase** capability'sini ekleyin

### 4. Info.plist Güncelleme

`ios/Runner/Info.plist` dosyasına SKAdNetworkItems ekleyin:

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

## 🔧 Test Etme

### Android Test
1. Play Console'da test kullanıcıları ekleyin
2. Alpha/Beta test track'e yükleyin
3. Test kullanıcılarıyla test edin

### iOS Test
1. TestFlight'a yükleyin
2. Sandbox test hesapları oluşturun
3. Test satın almaları yapın

## ⚠️ Önemli Notlar

1. **Receipt Validation**: Güvenlik için sunucu tarafında receipt doğrulaması yapılmalı
2. **Grace Period**: Ödeme sorunları için 3-7 günlük grace period eklenebilir
3. **Restore Purchases**: Kullanıcı cihaz değiştirdiğinde aboneliği geri yükleyebilmeli
4. **Cancellation**: Kullanıcı istediği zaman iptal edebilmeli

## 🚀 Production Checklist

- [ ] Google Play Console'da abonelik oluşturuldu
- [ ] App Store Connect'te abonelik oluşturuldu
- [ ] Android manifest'e billing permission eklendi
- [ ] iOS capabilities'e In-App Purchase eklendi
- [ ] Test satın almaları başarılı
- [ ] Receipt validation implementasyonu yapıldı
- [ ] Privacy Policy ve Terms of Service linkleri eklendi
- [ ] Abonelik yönetimi linki eklendi

## 📞 Destek
Sorunlar için: support@kavaid.com

## 🔗 Faydalı Linkler
- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
- [StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [Flutter In-App Purchase](https://pub.dev/packages/in_app_purchase)

# Abonelik Sistemi Kurulum Kılavuzu

## 1. Google Play Console Ayarları

### A. Google Play Console'da Ürün Oluşturma
1. [Google Play Console](https://play.google.com/console) hesabınıza giriş yapın
2. Uygulamanızı seçin
3. Sol menüden **Monetization** > **Products** > **Subscriptions** seçin
4. **Create subscription** butonuna tıklayın
5. Aşağıdaki bilgileri girin:
   - **Product ID**: `kavaid_monthly_subscription`
   - **Name**: Kavaid Premium Aylık
   - **Description**: Sınırsız kelime erişimi ve reklamsız deneyim
   - **Base plans and offers**:
     - **Price**: 60 TRY (Türkiye)
     - **Billing period**: 1 ay
     - **Grace period**: 3 gün
   
### B. Test Kullanıcıları Ekleme
1. **Setup** > **License testing** bölümüne gidin
2. Test e-posta adreslerini ekleyin
3. **License response** olarak **RESPOND_NORMALLY** seçin

## 2. iOS App Store Connect Ayarları

### A. App Store Connect'te Ürün Oluşturma
1. [App Store Connect](https://appstoreconnect.apple.com) hesabınıza giriş yapın
2. Uygulamanızı seçin
3. **Features** > **In-App Purchases** seçin
4. **+** butonuna tıklayın ve **Auto-Renewable Subscription** seçin
5. Aşağıdaki bilgileri girin:
   - **Reference Name**: Kavaid Premium Monthly
   - **Product ID**: `kavaid_monthly_subscription`
   - **Subscription Group**: Kavaid Premium
   - **Duration**: 1 Month
   - **Price**: Tier 8 (60 TRY)

### B. Subscription Group Oluşturma
1. **Subscription Group Reference Name**: Kavaid Premium
2. **Subscription Group Display Name**: Premium Üyelik

## 3. Android Uygulama Ayarları

### A. AndroidManifest.xml Güncellemesi
`android/app/src/main/AndroidManifest.xml` dosyasına billing permission ekleyin:
```xml
<uses-permission android:name="com.android.vending.BILLING" />
```

### B. build.gradle Güncellemesi
Zaten yapılandırılmış durumda.

## 4. iOS Uygulama Ayarları

### A. Info.plist Güncellemesi
Zaten yapılandırılmış durumda.

### B. Capabilities
Xcode'da projenizi açın ve **Signing & Capabilities** bölümünde **In-App Purchase** capability'sini ekleyin.

## 5. Test Etme

### Android'de Test
1. Uygulamayı Google Play Console'a yükleyin (Internal testing track)
2. Test kullanıcılarını davet edin
3. Test cihazında Google Play Store'dan uygulamayı indirin
4. Abonelik satın alma işlemini test edin

### iOS'te Test
1. TestFlight'a build yükleyin
2. Test kullanıcılarını davet edin
3. Sandbox hesabı ile test edin

## 6. Revenue Cat Entegrasyonu (Opsiyonel)

Daha kolay abonelik yönetimi için Revenue Cat kullanabilirsiniz:
1. [Revenue Cat](https://www.revenuecat.com) hesabı oluşturun
2. `purchases_flutter` paketini ekleyin
3. API anahtarlarınızı yapılandırın

## 7. Önemli Notlar

- **Test ortamında**: Test satın almaları gerçek para kullanmaz
- **Production'a geçmeden önce**: Tüm ürün bilgilerini ve fiyatları kontrol edin
- **Vergi**: Fiyatlar KDV dahil olmalıdır
- **Faturalandırma**: Google/Apple otomatik olarak faturalandırma işlemlerini yönetir

## 8. Sorun Giderme

### "Ürün bulunamadı" hatası
- Product ID'nin doğru yazıldığından emin olun
- Google Play Console'da ürünün aktif olduğundan emin olun
- Uygulamanın Play Store'a yüklenmiş olduğundan emin olun

### Satın alma başarısız
- Test kullanıcısı olarak eklendiğinizden emin olun
- İnternet bağlantınızı kontrol edin
- Google Play Store/App Store'un güncel olduğundan emin olun 