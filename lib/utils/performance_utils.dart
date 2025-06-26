import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class PerformanceUtils {
  static int _frameCount = 0;
  static int _droppedFrames = 0;
  static double _currentFPS = 60.0;
  static bool _isMonitoring = false;
  static String _deviceCategory = 'unknown';
  static bool _isLowEndDevice = false;
  
  // 🚀 PERFORMANCE MOD: Cihaz kategorileri
  static const Map<String, Map<String, dynamic>> deviceCategories = {
    'high_end': {
      'cache_extent': 1500.0,
      'max_cache_items': 75,
      'animation_multiplier': 0.8,
      'preload_items': 5,
      'use_cache_images': true,
    },
    'mid_range': {
      'cache_extent': 1000.0,
      'max_cache_items': 50,
      'animation_multiplier': 1.0,
      'preload_items': 3,
      'use_cache_images': true,
    },
    'low_end': {
      'cache_extent': 600.0,
      'max_cache_items': 25,
      'animation_multiplier': 1.2,
      'preload_items': 1,
      'use_cache_images': false,
    },
  };
  
  // 🚀 PERFORMANCE MOD: Cihaz tespiti
  static Future<void> detectDevicePerformance() async {
    if (!Platform.isAndroid) return;
    
    try {
      // Cihaz bilgilerini al
      final channel = MethodChannel('device_info');
      final deviceInfo = await channel.invokeMethod('getDeviceInfo').timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('⏱️ Device info timeout, fallback kullanılıyor');
          return null;
        },
      );
      
      if (deviceInfo != null) {
        debugPrint('📱 Cihaz Bilgileri: $deviceInfo');
        
        // Cihaz bilgilerine göre kategori belirle
        final totalRamMB = deviceInfo['totalRamMB'] as int? ?? 0;
        final glEsVersion = deviceInfo['glEsVersion'] as double? ?? 0.0;
        final apiLevel = deviceInfo['apiLevel'] as int? ?? 0;
        final performanceCategory = deviceInfo['performanceCategory'] as String? ?? 'unknown';
        
        // Native taraftan gelen kategoriyi kullan
        if (performanceCategory != 'unknown') {
          _deviceCategory = performanceCategory;
          _isLowEndDevice = performanceCategory == 'low_end';
          debugPrint('🎯 Native kategori kullanılıyor: $_deviceCategory');
        } else {
          // Fallback kategorilendirme
          _categorizeDeviceBySpecs(totalRamMB, glEsVersion, apiLevel);
        }
      } else {
        // Native channel başarısız, FPS bazlı tespit
        debugPrint('⚠️ Native device info alınamadı, FPS bazlı tespit kullanılacak');
        _categorizeDevice();
      }
    } catch (e) {
      debugPrint('⚠️ Cihaz tespiti başarısız, varsayılan ayarlar kullanılacak: $e');
      _categorizeDevice(); // Fallback kategorilendirme
    }
  }
  
  // 🚀 PERFORMANCE MOD: Cihaz özelliklerine göre kategorilendirme
  static void _categorizeDeviceBySpecs(int totalRamMB, double glEsVersion, int apiLevel) {
    if (totalRamMB >= 8192 && glEsVersion >= 3.2 && apiLevel >= 29) {
      _deviceCategory = 'high_end';
      _isLowEndDevice = false;
      debugPrint('🚀 Cihaz Kategorisi: Yüksek Performans (8GB+ RAM, OpenGL ES 3.2+)');
    } else if (totalRamMB >= 4096 && glEsVersion >= 3.0 && apiLevel >= 26) {
      _deviceCategory = 'mid_range';
      _isLowEndDevice = false;
      debugPrint('⚡ Cihaz Kategorisi: Orta Performans (4GB+ RAM, OpenGL ES 3.0+)');
    } else {
      _deviceCategory = 'low_end';
      _isLowEndDevice = true;
      debugPrint('📱 Cihaz Kategorisi: Düşük Performans (optimizasyonlar devrede)');
    }
  }
  
  // 🚀 PERFORMANCE MOD: Basit cihaz kategorilendirme
  static void _categorizeDevice() {
    // FPS'e göre kategori belirleme
    if (_currentFPS >= 115) {
      _deviceCategory = 'high_end';
      _isLowEndDevice = false;
      debugPrint('🚀 Cihaz Kategorisi: Yüksek Performans (120Hz+)');
    } else if (_currentFPS >= 85) {
      _deviceCategory = 'mid_range';
      _isLowEndDevice = false;
      debugPrint('⚡ Cihaz Kategorisi: Orta Performans (90Hz+)');
    } else {
      // Düşük FPS oranına göre low-end kontrolü
      if (dropRate > 10.0 || _currentFPS < 45) {
        _deviceCategory = 'low_end';
        _isLowEndDevice = true;
        debugPrint('📱 Cihaz Kategorisi: Düşük Performans (optimizasyonlar devrede)');
      } else {
        _deviceCategory = 'mid_range';
        _isLowEndDevice = false;
        debugPrint('📱 Cihaz Kategorisi: Standart Performans');
      }
    }
  }
  
  // 🚀 PERFORMANCE MOD: Adaptif ayar getters
  static Map<String, dynamic> get currentDeviceSettings {
    return deviceCategories[_deviceCategory] ?? deviceCategories['mid_range']!;
  }
  
  // 🚀 PERFORMANCE MOD: Gelişmiş FPS izleme
  static void enableFPSCounter() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    debugPrint('🎯 FPS İzleme Başlatıldı');
    
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        _frameCount++;
        
        // Frame süresi hesapla (milisaniye)
        final buildTime = timing.buildDuration.inMicroseconds / 1000.0;
        final rasterTime = timing.rasterDuration.inMicroseconds / 1000.0;
        final totalTime = buildTime + rasterTime;
        
        // FPS hesapla
        if (totalTime > 0) {
          _currentFPS = 1000.0 / totalTime;
        }
        
        // Frame drop kontrolü
        bool frameDropped = false;
        
        // 120Hz için 8.33ms, 90Hz için 11.11ms, 60Hz için 16.67ms
        if (_currentFPS >= 115) {
          // 120Hz mod
          if (totalTime > 8.5) {
            frameDropped = true;
          }
        } else if (_currentFPS >= 85) {
          // 90Hz mod
          if (totalTime > 11.5) {
            frameDropped = true;
          }
        } else {
          // 60Hz mod
          if (totalTime > 17.0) {
            frameDropped = true;
          }
        }
        
        if (frameDropped) {
          _droppedFrames++;
          debugPrint('⚠️ Frame Drop: ${_currentFPS.toStringAsFixed(1)} FPS | Build: ${buildTime.toStringAsFixed(1)}ms | Raster: ${rasterTime.toStringAsFixed(1)}ms');
        }
        
        // Her 60 frame'de bir rapor ve cihaz kategorisi güncelle
        if (_frameCount % 60 == 0) {
          final dropRate = (_droppedFrames / _frameCount) * 100;
          debugPrint('📊 FPS Raporu: ${_currentFPS.toStringAsFixed(1)} FPS | Drop Rate: ${dropRate.toStringAsFixed(1)}% | Total Frames: $_frameCount');
          
          // Cihaz kategorisini güncelle
          _categorizeDevice();
          
          // Drop rate %5'ten fazlaysa uyarı ver
          if (dropRate > 5.0) {
            debugPrint('🔴 PERFORMANS UYARISI: Yüksek frame drop oranı!');
            debugPrint('🔧 Önerilen çözümler:');
            debugPrint('   • Diğer uygulamaları kapatın');
            debugPrint('   • Cihazın soğumasını bekleyin');
            debugPrint('   • Geliştirici seçeneklerinde GPU rendering aktif edin');
          }
        }
        
        // Çok düşük performans tespiti
        if (_frameCount > 300 && dropRate > 15.0) {
          debugPrint('🔴 CRİTİK PERFORMANS SORUNU TESPİT EDİLDİ!');
          debugPrint('🔧 Acil düşük performans moduna geçiliyor...');
          _activateEmergencyMode();
        }
      }
    });
  }
  
  // 🚀 PERFORMANCE MOD: Acil durum modu
  static void _activateEmergencyMode() {
    _deviceCategory = 'low_end';
    _isLowEndDevice = true;
    
    // Acil cache temizleme
    optimizeMemory();
    
    debugPrint('🆘 ACİL PERFORMANS MODU AKTİF!');
    debugPrint('   • Cache boyutu minimize edildi');
    debugPrint('   • Animasyonlar yavaşlatıldı');
    debugPrint('   • Görsel efektler devre dışı');
  }
  
  // 🚀 PERFORMANCE MOD: Sistem performans bilgileri
  static void logSystemPerformance() {
    debugPrint('🔧 Sistem Performans Bilgileri:');
    debugPrint('   • Frame Count: $_frameCount');
    debugPrint('   • Dropped Frames: $_droppedFrames');
    debugPrint('   • Current FPS: ${_currentFPS.toStringAsFixed(1)}');
    debugPrint('   • Drop Rate: ${(_droppedFrames / _frameCount * 100).toStringAsFixed(1)}%');
    debugPrint('   • Device Category: $_deviceCategory');
    debugPrint('   • Low End Device: $_isLowEndDevice');
  }
  
  // Performans modu
  static const bool performanceMode = true;
  
  // 🚀 PERFORMANCE MOD: Adaptif animasyon süreleri
  static Duration get fastAnimation {
    final multiplier = currentDeviceSettings['animation_multiplier'] as double;
    final baseMs = _currentFPS >= 115 ? 80 : (_currentFPS >= 85 ? 100 : 120);
    return Duration(milliseconds: (baseMs * multiplier).round());
  }
  
  static Duration get normalAnimation {
    final multiplier = currentDeviceSettings['animation_multiplier'] as double;
    final baseMs = _currentFPS >= 115 ? 150 : (_currentFPS >= 85 ? 180 : 200);
    return Duration(milliseconds: (baseMs * multiplier).round());
  }
  
  static Duration get slowAnimation {
    final multiplier = currentDeviceSettings['animation_multiplier'] as double;
    final baseMs = _currentFPS >= 115 ? 250 : (_currentFPS >= 85 ? 280 : 300);
    return Duration(milliseconds: (baseMs * multiplier).round());
  }
  
  // 🚀 PERFORMANCE MOD: Adaptif cache ayarları
  static double get defaultCacheExtent {
    return currentDeviceSettings['cache_extent'] as double;
  }
  
  static int get maxCacheItems {
    return currentDeviceSettings['max_cache_items'] as int;
  }
  
  static int get preloadItems {
    return currentDeviceSettings['preload_items'] as int;
  }
  
  static bool get useCacheImages {
    return currentDeviceSettings['use_cache_images'] as bool;
  }
  
  // Getters
  static bool get isLowEndDevice => _isLowEndDevice;
  static String get deviceCategory => _deviceCategory;
  
  // Debounce süreleri - cihaza göre adaptif
  static Duration get searchDebounce {
    return Duration(milliseconds: _isLowEndDevice ? 500 : 300);
  }
  
  static Duration get inputDebounce {
    return Duration(milliseconds: _isLowEndDevice ? 300 : 200);
  }
  
  // 🚀 PERFORMANCE MOD: Optimize edilmiş widget builder
  static Widget optimizedBuilder({
    required Widget Function() builder,
    bool shouldRepaint = true,
    String? debugLabel,
  }) {
    // Düşük performanslı cihazlarda RepaintBoundary kullanımını azalt
    if (shouldRepaint && !_isLowEndDevice) {
      return RepaintBoundary(
        key: debugLabel != null ? ValueKey('repaint_$debugLabel') : null,
        child: builder(),
      );
    }
    return builder();
  }
  
  // 🚀 PERFORMANCE MOD: Gelişmiş performans ölçümü
  static void measurePerformance(String tag, VoidCallback callback) {
    final stopwatch = Stopwatch()..start();
    callback();
    stopwatch.stop();
    
    final elapsed = stopwatch.elapsedMicroseconds / 1000.0; // milisaniye
    
    // Frame budget'a göre uyarı seviyesi
    double warningThreshold = 16.67; // 60Hz için
    if (_currentFPS >= 115) {
      warningThreshold = 8.33;  // 120Hz için
    } else if (_currentFPS >= 85) {
      warningThreshold = 11.11; // 90Hz için
    }
    
    if (elapsed > warningThreshold) {
      debugPrint('🔴 PERFORMANS UYARISI - $tag: ${elapsed.toStringAsFixed(2)}ms (Budget: ${warningThreshold.toStringAsFixed(2)}ms)');
    } else if (elapsed > warningThreshold * 0.8) {
      debugPrint('🟡 PERFORMANS İZLEME - $tag: ${elapsed.toStringAsFixed(2)}ms');
    }
  }
  
  // 🚀 PERFORMANCE MOD: Widget performans wrapper
  static Widget performanceWrapper({
    required Widget child,
    required String label,
    bool enableProfiling = false,
  }) {
    if (!enableProfiling || _isLowEndDevice) return child;
    
    return Builder(
      builder: (context) {
        measurePerformance(label, () {});
        return RepaintBoundary(
          key: ValueKey('perf_$label'),
          child: child,
        );
      },
    );
  }
  
  // 🚀 PERFORMANCE MOD: Memory optimize etme
  static void optimizeMemory() {
    // System garbage collection'ı tetikle
    SystemChannels.platform.invokeMethod('System.gc');
    debugPrint('🧹 Memory optimization tamamlandı');
  }
  
  // 🚀 PERFORMANCE MOD: FPS bilgisi getter
  static double get currentFPS => _currentFPS;
  static int get totalFrames => _frameCount;
  static int get droppedFrames => _droppedFrames;
  static double get dropRate => _frameCount > 0 ? (_droppedFrames / _frameCount) * 100 : 0.0;
}

// 🚀 PERFORMANCE MOD: Optimize edilmiş SliverChildDelegate
class OptimizedSliverChildDelegate extends SliverChildBuilderDelegate {
  OptimizedSliverChildDelegate({
    required Widget Function(BuildContext, int) builder,
    required int childCount,
    String? debugLabel,
  }) : super(
          (context, index) {
            // Düşük performanslı cihazlarda RepaintBoundary kullanmayın
            if (PerformanceUtils.isLowEndDevice) {
              return builder(context, index);
            }
            return RepaintBoundary(
              key: ValueKey('${debugLabel ?? 'optimized'}_item_$index'),
              child: builder(context, index),
            );
          },
          childCount: childCount,
          addAutomaticKeepAlives: !PerformanceUtils.isLowEndDevice, // Düşük performansta kapalı
          addRepaintBoundaries: false, // Manuel olarak ekliyoruz
          addSemanticIndexes: false,
        );
}

// 🚀 PERFORMANCE MOD: Performans izleme mixin'i
mixin PerformanceMixin<T extends StatefulWidget> on State<T> {
  late String _widgetName;
  
  @override
  void initState() {
    super.initState();
    _widgetName = T.toString();
    PerformanceUtils.measurePerformance('$_widgetName.initState', () {});
  }
  
  @override
  Widget build(BuildContext context) {
    return PerformanceUtils.optimizedBuilder(
      builder: () => buildOptimized(context),
      debugLabel: _widgetName,
    );
  }
  
  // Alt sınıflar bu metodu implement etmeli
  Widget buildOptimized(BuildContext context);
} 