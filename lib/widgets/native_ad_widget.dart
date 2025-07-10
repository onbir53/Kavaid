import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// MAIN: Optimized Native Ad Widget (now stateless)
class NativeAdWidget extends StatelessWidget {
  final NativeAd ad;

  // Reklamın ve yer tutucunun sabit yüksekliği
  static const double adHeight = 340.0;

  const NativeAdWidget({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: adHeight,
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF48484A).withOpacity(0.3)
                : const Color(0xFFE5E5EA).withOpacity(0.5),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
