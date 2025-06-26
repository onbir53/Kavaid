import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class PerformanceUtils {
  static int _frameCount = 0;
  static int _droppedFrames = 0;
  static double _currentFPS = 60.0;
  static bool _isMonitoring = false;
  
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
        
        // Her 60 frame'de bir rapor
        if (_frameCount % 60 == 0) {
          final dropRate = (_droppedFrames / _frameCount) * 100;
          debugPrint('📊 FPS Raporu: ${_currentFPS.toStringAsFixed(1)} FPS | Drop Rate: ${dropRate.toStringAsFixed(1)}% | Total Frames: $_frameCount');
          
          // Drop rate %5'ten fazlaysa uyarı ver
          if (dropRate > 5.0) {
            debugPrint('🔴 PERFORMANS UYARISI: Yüksek frame drop oranı!');
          }
        }
      }
    });
  }
  
  // 🚀 PERFORMANCE MOD: Sistem performans bilgileri
  static void logSystemPerformance() {
    debugPrint('🔧 Sistem Performans Bilgileri:');
    debugPrint('   • Frame Count: $_frameCount');
    debugPrint('   • Dropped Frames: $_droppedFrames');
    debugPrint('   • Current FPS: ${_currentFPS.toStringAsFixed(1)}');
    debugPrint('   • Drop Rate: ${(_droppedFrames / _frameCount * 100).toStringAsFixed(1)}%');
  }
  
  // Performans modu
  static const bool performanceMode = true;
  
  // 🚀 PERFORMANCE MOD: FPS'e göre optimize edilmiş animasyon süreleri
  static Duration get fastAnimation {
    if (_currentFPS >= 115) return const Duration(milliseconds: 80);   // 120Hz
    if (_currentFPS >= 85) return const Duration(milliseconds: 100);   // 90Hz
    return const Duration(milliseconds: 120);                          // 60Hz
  }
  
  static Duration get normalAnimation {
    if (_currentFPS >= 115) return const Duration(milliseconds: 150);  // 120Hz
    if (_currentFPS >= 85) return const Duration(milliseconds: 180);   // 90Hz
    return const Duration(milliseconds: 200);                          // 60Hz
  }
  
  static Duration get slowAnimation {
    if (_currentFPS >= 115) return const Duration(milliseconds: 250);  // 120Hz
    if (_currentFPS >= 85) return const Duration(milliseconds: 280);   // 90Hz
    return const Duration(milliseconds: 300);                          // 60Hz
  }
  
  // 🚀 PERFORMANCE MOD: FPS'e göre optimize edilmiş cache ayarları
  static double get defaultCacheExtent {
    if (_currentFPS >= 115) return 1500.0;  // 120Hz - daha büyük cache
    if (_currentFPS >= 85) return 1200.0;   // 90Hz - orta cache
    return 1000.0;                          // 60Hz - standart cache
  }
  
  static int get maxCacheItems {
    if (_currentFPS >= 115) return 75;      // 120Hz - daha fazla item
    if (_currentFPS >= 85) return 60;       // 90Hz - orta item
    return 50;                              // 60Hz - standart item
  }
  
  // Debounce süreleri
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration inputDebounce = Duration(milliseconds: 200);
  
  // 🚀 PERFORMANCE MOD: Optimize edilmiş widget builder
  static Widget optimizedBuilder({
    required Widget Function() builder,
    bool shouldRepaint = true,
    String? debugLabel,
  }) {
    if (shouldRepaint) {
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
    if (!enableProfiling) return child;
    
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
          (context, index) => RepaintBoundary(
            key: ValueKey('${debugLabel ?? 'optimized'}_item_$index'),
            child: builder(context, index),
          ),
          childCount: childCount,
          addAutomaticKeepAlives: true,
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