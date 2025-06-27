import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import '../models/word_model.dart';
import '../services/saved_words_service.dart';
import '../utils/performance_utils.dart';

class WordCard extends StatefulWidget {
  final WordModel word;

  const WordCard({
    super.key,
    required this.word,
  });

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  final SavedWordsService _savedWordsService = SavedWordsService();
  late bool _isSaved;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Başlangıçta sync kontrolü yap
    _isSaved = _savedWordsService.isWordSavedSync(widget.word);
    
    // SavedWordsService'i dinle
    _savedWordsService.addListener(_updateSavedStatus);
    
    // Async kontrolü de yap güvenlik için
    _checkSavedStatus();
  }

  @override
  void didUpdateWidget(WordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget güncellendiğinde kelime değiştiyse durumu güncelle
    if (oldWidget.word.kelime != widget.word.kelime) {
      _isSaved = _savedWordsService.isWordSavedSync(widget.word);
      _checkSavedStatus();
    }
  }

  @override
  void dispose() {
    // Listener'ı kaldır
    _savedWordsService.removeListener(_updateSavedStatus);
    super.dispose();
  }

  void _updateSavedStatus() {
    if (mounted) {
      final newSavedStatus = _savedWordsService.isWordSavedSync(widget.word);
      if (newSavedStatus != _isSaved) {
        setState(() {
          _isSaved = newSavedStatus;
        });
      }
    }
  }

  Future<void> _checkSavedStatus() async {
    final isSaved = await _savedWordsService.isWordSaved(widget.word);
    if (mounted && isSaved != _isSaved) {
      setState(() {
        _isSaved = isSaved;
      });
    }
  }

  Future<void> _toggleSaved() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      bool success;
      if (_isSaved) {
        success = await _savedWordsService.removeWord(widget.word);
      } else {
        success = await _savedWordsService.saveWord(widget.word);
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İşlem başarısız oldu'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Toggle saved error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem başarısız: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 🚀 PERFORMANCE MOD: RepaintBoundary ile sarmalama
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _isLoading ? null : _toggleSaved,
        child: AnimatedContainer(
          duration: PerformanceUtils.fastAnimation,
          curve: Curves.easeInOut,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // 🚀 PERFORMANCE MOD: Gradient kaldırıldı, solid renk kullanıldı
            color: isDarkMode 
                ? const Color(0xFF2C2C2E) 
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode 
                  ? const Color(0xFF3A3A3C)
                  : const Color(0xFFE5E5EA),
              width: 1,
            ),
            // 🚀 PERFORMANCE MOD: Shadow optimizasyonu
            boxShadow: PerformanceUtils.enableShadows ? [
              BoxShadow(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arapça kelime
              Text(
                widget.word.harekeliKelime ?? widget.word.kelime,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  height: 1.5,
                  fontFeatures: const [
                    ui.FontFeature.enable('liga'),
                    ui.FontFeature.enable('calt'),
                  ],
                ),
                textDirection: TextDirection.rtl,
              ),
              
              // Türkçe anlam
              if (widget.word.anlam != null && widget.word.anlam!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.word.anlam!,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode 
                        ? const Color(0xFF8E8E93)
                        : const Color(0xFF6D6D70),
                    height: 1.5,
                  ),
                ),
              ],
              
              // Örnek cümle - sadece genişletildiğinde göster
              if (widget.word.ornekler.isNotEmpty) ...[
                const SizedBox(height: 16),
                
                // Örnek cümle başlığı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? const Color(0xFF007AFF).withOpacity(0.1)
                        : const Color(0xFF007AFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Örnek Cümle',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF007AFF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Arapça örnek cümle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? const Color(0xFF1C1C1E).withOpacity(0.5)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode 
                          ? const Color(0xFF3A3A3C).withOpacity(0.5)
                          : const Color(0xFFE5E5EA).withOpacity(0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.word.ornekler.first.arapcaCumle,
                        style: GoogleFonts.scheherazadeNew(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode 
                              ? Colors.white.withOpacity(0.9)
                              : const Color(0xFF1C1C1E),
                          height: 1.6,
                          fontFeatures: const [
                            ui.FontFeature.enable('liga'),
                            ui.FontFeature.enable('calt'),
                          ],
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      
                      if (widget.word.ornekler.first.turkceCeviri.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.word.ornekler.first.turkceCeviri,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode 
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF6D6D70),
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              
              // Genişlet/Daralt göstergesi
              if (_isLoading) ...[
                const SizedBox(height: 12),
                Center(
                  child: CircularProgressIndicator(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Center(
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 24,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
}

// Özellik chip'leri
class _FeatureChips extends StatelessWidget {
  final Map<String, dynamic> features;
  final bool isDarkMode;

  const _FeatureChips({
    required this.features,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: features.entries
          .where((entry) => entry.key != 'cogulForm')
          .map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF3A3A3C).withOpacity(0.8)
                : const Color(0xFFE8F0FF), // Daha mavi tonlu chip arka planı
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode 
                  ? const Color(0xFF48484A)
                  : const Color(0xFFB8D4F5), // Daha mavi tonlu kenar
              width: 0.7,
            ),
            boxShadow: [
              if (!isDarkMode) ...[
                BoxShadow(
                  color: const Color(0xFF007AFF).withOpacity(0.05), // Mavi gölge
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  blurRadius: 1,
                  offset: const Offset(0, -0.5),
                ),
              ],
            ],
          ),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: TextStyle(
              fontSize: 14, // 13'ten 14'e büyüttüm
              color: isDarkMode 
                  ? const Color(0xFFE5E5EA)
                  : const Color(0xFF2C5AA0), // Daha belirgin mavi metin
              fontWeight: FontWeight.w600, // w500'den w600'e
              letterSpacing: 0.3,
            ),
          ),
        );
      }).toList(),
    );
  }
} 