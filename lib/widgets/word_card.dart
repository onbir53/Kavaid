import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import '../models/word_model.dart';
import '../services/saved_words_service.dart';
import '../utils/performance_utils.dart';

// 🚀 PERFORMANCE: Font'u bir kere yükle ve cache'le
class _FontCache {
  static TextStyle? _arabicStyle;
  static TextStyle? _exampleArabicStyle;
  
  static TextStyle getArabicStyle() {
    _arabicStyle ??= GoogleFonts.scheherazadeNew(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.5,
      fontFeatures: const [
        ui.FontFeature.enable('liga'),
        ui.FontFeature.enable('calt'),
      ],
    );
    return _arabicStyle!;
  }
  
  static TextStyle getExampleArabicStyle() {
    _exampleArabicStyle ??= GoogleFonts.scheherazadeNew(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.6,
      fontFeatures: const [
        ui.FontFeature.enable('liga'),
        ui.FontFeature.enable('calt'),
      ],
    );
    return _exampleArabicStyle!;
  }
}

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
  
  // 🚀 PERFORMANCE: Listener'ı optimize et
  bool _isListenerActive = false;

  @override
  void initState() {
    super.initState();
    // Başlangıçta sync kontrolü yap
    _isSaved = _savedWordsService.isWordSavedSync(widget.word);
    
    // 🚀 PERFORMANCE: Listener'ı delayed olarak ekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _savedWordsService.addListener(_updateSavedStatus);
        _isListenerActive = true;
      }
    });
  }

  @override
  void didUpdateWidget(WordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget güncellendiğinde kelime değiştiyse durumu güncelle
    if (oldWidget.word.kelime != widget.word.kelime) {
      _isSaved = _savedWordsService.isWordSavedSync(widget.word);
    }
  }

  @override
  void dispose() {
    // Listener'ı kaldır
    if (_isListenerActive) {
      _savedWordsService.removeListener(_updateSavedStatus);
    }
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
    
    // 🚀 PERFORMANCE: RepaintBoundary ile sarmalama ve key kullanımı
    return RepaintBoundary(
      key: ValueKey('word_card_${widget.word.kelime}'),
      child: GestureDetector(
        onTap: _isLoading ? null : _toggleSaved,
        child: Container( // 🚀 PERFORMANCE: AnimatedContainer yerine normal Container
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // 🚀 PERFORMANCE: Gradient kaldırıldı, solid renk kullanıldı
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
            // 🚀 PERFORMANCE: Shadow optimizasyonu
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
          // 🚀 PERFORMANCE: Basitleştirilmiş widget tree
          child: _buildCardContent(isDarkMode),
        ),
      ),
    );
  }
  
  // 🚀 PERFORMANCE: İçeriği ayrı method'a al
  Widget _buildCardContent(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // 🚀 PERFORMANCE: Column boyutunu minimize et
      children: [
        // Arapça kelime - 🚀 PERFORMANCE: Cache'lenmiş font stili
        Text(
          widget.word.harekeliKelime ?? widget.word.kelime,
          style: _FontCache.getArabicStyle().copyWith(
            color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
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
        
        // 🚀 PERFORMANCE: Örnek cümle widget'ını optimize et
        if (widget.word.ornekler.isNotEmpty)
          _buildExampleSection(isDarkMode),
        
        // Kaydetme göstergesi
        const SizedBox(height: 12),
        Center(
          child: _isLoading 
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                )
              : Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 24,
                ),
        ),
      ],
    );
  }
  
  // 🚀 PERFORMANCE: Örnek cümle bölümünü ayrı widget olarak optimize et
  Widget _buildExampleSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        
        // Örnek cümle başlığı - 🚀 PERFORMANCE: const widget kullan
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF007AFF).withOpacity(0.1)
                : const Color(0xFF007AFF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Örnek Cümle',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF007AFF),
              letterSpacing: 0.5,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 🚀 PERFORMANCE: RepaintBoundary ile örnek cümle container'ını izole et
        RepaintBoundary(
          child: Container(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🚀 PERFORMANCE: Cache'lenmiş font stili kullan
                Text(
                  widget.word.ornekler.first.arapcaCumle,
                  style: _FontCache.getExampleArabicStyle().copyWith(
                    color: isDarkMode 
                        ? Colors.white.withOpacity(0.9)
                        : const Color(0xFF1C1C1E),
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
        ),
      ],
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