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

// 🚀 PERFORMANCE: StatelessWidget'a dönüştür ve ValueListenableBuilder kullan
class WordCard extends StatelessWidget {
  final WordModel word;

  const WordCard({
    super.key,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final savedWordsService = SavedWordsService();
    
    // 🚀 PERFORMANCE: RepaintBoundary ile sarmalama ve key kullanımı
    return RepaintBoundary(
      key: ValueKey('word_card_${word.kelime}'),
      child: ValueListenableBuilder<bool>(
        valueListenable: savedWordsService.isWordSavedNotifier(word),
        builder: (context, isSaved, child) {
          return GestureDetector(
            onTap: () => _toggleSaved(context, savedWordsService, isSaved),
            child: Container(
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
              child: _buildCardContent(isDarkMode, isSaved),
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _toggleSaved(BuildContext context, SavedWordsService service, bool isSaved) async {
    try {
      if (isSaved) {
        await service.removeWord(word);
      } else {
        await service.saveWord(word);
      }
    } catch (e) {
      print('Toggle saved error: $e');
    }
  }
  
  // 🚀 PERFORMANCE: İçeriği ayrı method'a al
  Widget _buildCardContent(bool isDarkMode, bool isSaved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // 🚀 PERFORMANCE: Column boyutunu minimize et
      children: [
        // Arapça kelime - 🚀 PERFORMANCE: Cache'lenmiş font stili
        Text(
          word.harekeliKelime ?? word.kelime,
          style: _FontCache.getArabicStyle().copyWith(
            color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
          ),
          textDirection: TextDirection.rtl,
        ),
        
        // Türkçe anlam
        if (word.anlam != null && word.anlam!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            word.anlam!,
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
        if (word.ornekler.isNotEmpty)
          _buildExampleSection(isDarkMode),
        
        // Kaydetme göstergesi
        const SizedBox(height: 12),
        Center(
          child: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
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
                  word.ornekler.first.arapcaCumle,
                  style: _FontCache.getExampleArabicStyle().copyWith(
                    color: isDarkMode 
                        ? Colors.white.withOpacity(0.9)
                        : const Color(0xFF1C1C1E),
                  ),
                  textDirection: TextDirection.rtl,
                ),
                
                if (word.ornekler.first.turkceCeviri.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    word.ornekler.first.turkceCeviri,
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