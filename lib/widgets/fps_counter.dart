import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FPSCounter extends StatefulWidget {
  const FPSCounter({super.key});

  @override
  State<FPSCounter> createState() => _FPSCounterState();
}

class _FPSCounterState extends State<FPSCounter> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _frameCount = 0;
  int _fps = 0;
  DateTime _lastUpdate = DateTime.now();
  
  // FPS geçmişi ve ortalama hesaplama için
  final List<int> _fpsHistory = [];
  static const int _historySize = 60; // Son 60 frame
  
  @override
  void initState() {
    super.initState();
    
    // Frame callback'ini kaydet
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    
    // FPS'i her saniye güncelle
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastUpdate).inMilliseconds;
      
      if (elapsed > 0) {
        setState(() {
          _fps = (_frameCount * 1000 / elapsed).round();
          
          // FPS geçmişine ekle
          _fpsHistory.add(_fps);
          if (_fpsHistory.length > _historySize) {
            _fpsHistory.removeAt(0);
          }
          
          _frameCount = 0;
          _lastUpdate = now;
        });
      }
    });
  }
  
  void _onFrame(Duration timestamp) {
    _frameCount++;
  }
  
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  Color _getFPSColor() {
    if (_fps >= 55) return Colors.green;
    if (_fps >= 30) return Colors.orange;
    return Colors.red;
  }
  
  double get _averageFPS {
    if (_fpsHistory.isEmpty) return 0;
    final sum = _fpsHistory.reduce((a, b) => a + b);
    return sum / _fpsHistory.length;
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getFPSColor().withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.speed,
                    size: 16,
                    color: _getFPSColor(),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_fps FPS',
                    style: TextStyle(
                      color: _getFPSColor(),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              if (_fpsHistory.length >= 10) // En az 10 frame sonra ortalama göster
                Text(
                  'Ort: ${_averageFPS.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: (isDarkMode ? Colors.white70 : Colors.black54),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 