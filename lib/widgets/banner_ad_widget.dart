import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({Key? key}) : super(key: key);

  @override
  State<BannerAdWidget> createState() => BannerAdWidgetState();
}

class BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  AdSize? _adSize;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }



  Future<void> _loadBannerAd() async {
    // Web'de veya desteklenmeyen platformlarda reklam yükleme
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    // Önceki banneri dispose et
    await _bannerAd?.dispose();
    setState(() {
      _bannerAd = null;
      _isAdLoaded = false;
      _adSize = null;
    });

    // Ekran genişliğini al - tam genişlik
    final screenWidth = MediaQuery.of(context).size.width;
    print('🖥️ Ekran genişliği: $screenWidth');
    
    // Adaptive Banner boyutunu al - tam ekran genişliği
    final AdSize? adaptiveSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      screenWidth.truncate(),
    );

    if (adaptiveSize == null) {
      print('❌ Adaptive banner boyutu alınamadı');
      return;
    }

    print('📏 Adaptive banner boyutu: ${adaptiveSize.width}x${adaptiveSize.height}');

    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      size: adaptiveSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          print('📱 Adaptive Banner reklam yüklendi');
          
          // Banner yüklendikten sonra gerçek boyutunu al
          final BannerAd bannerAd = ad as BannerAd;
          final AdSize? platformSize = await bannerAd.getPlatformAdSize();
          
          if (platformSize == null) {
            print('❌ Platform ad boyutu alınamadı');
            return;
          }

          print('📏 Platform banner boyutu: ${platformSize.width}x${platformSize.height}');

          setState(() {
            _bannerAd = bannerAd;
            _isAdLoaded = true;
            _adSize = platformSize;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Adaptive Banner reklam yüklenemedi: $error');
          ad.dispose();
          setState(() {
            _bannerAd = null;
            _isAdLoaded = false;
            _adSize = null;
          });
        },
        onAdOpened: (ad) {
          print('📱 Banner reklam açıldı');
        },
        onAdClosed: (ad) {
          print('📱 Banner reklam kapandı');
        },
        onAdImpression: (ad) {
          print('📱 Banner reklam gösterildi');
        },
      ),
    );

    await _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Web'de veya desteklenmeyen platformlarda boş alan döndür
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return const SizedBox.shrink();
    }

    // Reklam yüklü ve boyut bilgisi varsa göster
    if (_bannerAd != null && _isAdLoaded && _adSize != null) {
      return Container(
        width: MediaQuery.of(context).size.width, // Tam ekran genişliği
        height: _adSize!.height.toDouble(),
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: OverflowBox(
          maxWidth: MediaQuery.of(context).size.width,
          minWidth: MediaQuery.of(context).size.width,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: _adSize!.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      );
    } else {
      // Reklam yüklenene kadar placeholder - tam genişlik
      return Container(
        width: MediaQuery.of(context).size.width, // Tam ekran genişliği
        height: 60,
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
  }
} 