import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// MAIN: Optimized Native Ad Widget (now stateless)
class NativeAdWidget extends StatelessWidget {
  final NativeAd ad;

  const NativeAdWidget({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, // Reklam yüksekliğini 80 piksel olarak sabitle
      padding: const EdgeInsets.only(bottom: 3),
      child: AdWidget(ad: ad),
    );
  }
}
