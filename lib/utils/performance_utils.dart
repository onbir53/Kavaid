import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PerformanceUtils {
  // FPS izleme için
  static void enableFPSCounter(BuildContext context) {
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        if (timing.rasterDuration.inMilliseconds > 16) {
          debugPrint('⚠️ FPS düştü: ${(1000 / timing.rasterDuration.inMilliseconds).toStringAsFixed(1)} FPS');
        }
      }
    });
  }
  
  // Performans modu
  static const bool performanceMode = true;
  
  // Animasyon süreleri
  static const Duration fastAnimation = Duration(milliseconds: 120);
  static const Duration normalAnimation = Duration(milliseconds: 200);
  static const Duration slowAnimation = Duration(milliseconds: 300);
  
  // Cache ayarları
  static const double defaultCacheExtent = 1000.0;
  static const int maxCacheItems = 50;
  
  // Debounce süreleri
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const Duration inputDebounce = Duration(milliseconds: 200);
  
  // Widget optimize edilmiş builder
  static Widget optimizedBuilder({
    required Widget Function() builder,
    bool shouldRepaint = true,
  }) {
    if (shouldRepaint) {
      return RepaintBoundary(child: builder());
    }
    return builder();
  }
  
  // Performans ölçümü
  static void measurePerformance(String tag, VoidCallback callback) {
    final stopwatch = Stopwatch()..start();
    callback();
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 16) {
      debugPrint('⏱️ $tag: ${stopwatch.elapsedMilliseconds}ms');
    }
  }
}

// Optimize edilmiş SliverChildDelegate
class OptimizedSliverChildDelegate extends SliverChildBuilderDelegate {
  OptimizedSliverChildDelegate({
    required Widget Function(BuildContext, int) builder,
    required int childCount,
  }) : super(
          (context, index) => RepaintBoundary(
            key: ValueKey('optimized_item_$index'),
            child: builder(context, index),
          ),
          childCount: childCount,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: false, // Manuel olarak ekliyoruz
          addSemanticIndexes: false,
        );
} 