# Windows PowerShell için iOS geliştirme ortamı kurulum ve çalıştırma betiği

function Check-Command($command) {
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

function Install-CocoaPods {
    Write-Host "CocoaPods yükleniyor..."
    try {
        # Ruby yüklü mü diye kontrol et
        if (-not (Check-Command "ruby")) {
            Write-Host "HATA: Ruby yüklü değil. Lütfen önce Ruby yükleyin:"
            Write-Host "1. https://rubyinstaller.org/ adresinden Ruby Installer'ı indirin"
            Write-Host "2. Kurulum sırasında 'Add Ruby to PATH' seçeneğini işaretleyin"
            Write-Host "3. Kurulum tamamlandıktan sonra PowerShell'i yeniden başlatın"
            exit 1
        }
        
        # CocoaPods'u yükle
        gem install cocoapods
        
        # Yükleme başarılı oldu mu kontrol et
        if (-not (Check-Command "pod")) {
            Write-Host "HATA: CocoaPods yüklenirken bir hata oluştu. Lütfen manuel olarak yükleyin:"
            Write-Host "1. PowerShell'i yönetici olarak açın"
            Write-Host "2. Şu komutu çalıştırın: gem install cocoapods"
            exit 1
        }
        
        Write-Host "CocoaPods başarıyla yüklendi."
    } catch {
        Write-Host "HATA: CocoaPods yüklenirken bir hata oluştu: $_"
        exit 1
    }
}

# Ana işlem
Write-Host "=== iOS Geliştirme Ortamı Kurulumu ==="

# CocoaPods yüklü mü kontrol et
if (-not (Check-Command "pod")) {
    Write-Host "CocoaPods bulunamadı. Yükleme başlatılıyor..."
    Install-CocoaPods
}

Write-Host "=== Flutter Projesi Hazırlanıyor ==="

# Flutter temizleme
Write-Host "Flutter temizleniyor..."
flutter clean

# Eski dosyaları temizle
Write-Host "Eski dosyalar temizleniyor..."
if (Test-Path "ios\Pods") { 
    Remove-Item -Recurse -Force "ios\Pods" 
    Write-Host "ios/Pods klasörü silindi"
}

if (Test-Path "ios\Podfile.lock") { 
    Remove-Item -Force "ios\Podfile.lock"
    Write-Host "ios/Podfile.lock dosyası silindi"
}

# Bağımlılıkları yükle
Write-Host "Flutter bağımlılıkları yükleniyor..."
flutter pub get

# Pub cache onar
Write-Host "Pub cache onarılıyor..."
flutter pub cache repair

# Build runner çalıştır
Write-Host "Build runner çalışıyor..."
flutter pub run build_runner build --delete-conflicting-outputs

# iOS bağımlılıklarını yükle
Write-Host "iOS bağımlılıkları yükleniyor..."
Set-Location ios
& pod install --repo-update
Set-Location ..

# Uygulamayı başlat
Write-Host "Uygulama başlatılıyor..."
flutter run
