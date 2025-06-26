import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 🚀 PERFORMANCE MOD: Image cache ve memory yönetimi
class ImageCacheManager {
  static bool _isInitialized = false;
  
  static void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    
    // 🚀 Image cache boyutunu artır (varsayılan 100MB yerine 200MB)
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200 MB
    
    // 🚀 Maksimum image sayısını artır (varsayılan 1000 yerine 2000)
    PaintingBinding.instance.imageCache.maximumSize = 2000;
    
    debugPrint('🖼️ Image cache optimized: 200MB, 2000 images max');
  }
  
  // 🚀 Memory baskısı durumunda cache'i temizle
  static void handleMemoryPressure() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Garbage collection tetikle
    SystemChannels.platform.invokeMethod('System.gc');
    
    debugPrint('🧹 Image cache cleared due to memory pressure');
  }
  
  // 🚀 Uygulama arka plana geçtiğinde cache'i optimize et
  static void optimizeForBackground() {
    // Cache boyutunu küçült
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB
    
    // Cache temizliği yap
    if (PaintingBinding.instance.imageCache.currentSizeBytes > (50 << 20)) {
      PaintingBinding.instance.imageCache.clear();
    }
    
    debugPrint('📉 Image cache reduced for background: 50MB');
  }
  
  // 🚀 Uygulama ön plana geldiğinde cache'i restore et
  static void restoreForForeground() {
    // Cache boyutunu geri yükle
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200 MB
    
    debugPrint('📈 Image cache restored for foreground: 200MB');
  }
} 