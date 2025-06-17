import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import '../models/word_model.dart';
import '../services/saved_words_service.dart';

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
  bool _isSaved = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _updateSavedStatus();
    
    // SavedWordsService'i dinle
    _savedWordsService.addListener(_updateSavedStatus);
  }

  @override
  void dispose() {
    // Listener'ı kaldır
    _savedWordsService.removeListener(_updateSavedStatus);
    super.dispose();
  }

  void _updateSavedStatus() {
    if (mounted) {
      setState(() {
        _isSaved = _savedWordsService.isWordSavedSync(widget.word);
      });
    }
  }

  Future<void> _toggleSaved() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSaved) {
        await _savedWordsService.removeWord(widget.word);
      } else {
        await _savedWordsService.saveWord(widget.word);
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Toggle saved error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isDarkMode 
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFFAFAFA),
                ],
              ),
        color: isDarkMode ? const Color(0xFF1C1C1E) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode 
              ? const Color(0xFF48484A)
              : const Color(0xFFE5E5EA),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : const Color(0xFF007AFF).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          if (!isDarkMode) ...[
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 1,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
          ],
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ana kelime
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.word.kelime,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _toggleSaved,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF007AFF),
                            ),
                          )
                        : Icon(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: const Color(0xFF007AFF),
                            size: 28,
                          ),
                  ),
                ),
              ],
            ),
            
            // Harekeli yazılış
            if (widget.word.harekeliKelime?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                widget.word.harekeliKelime!,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 28, // Biraz büyüttüm
                  fontWeight: FontWeight.w700, // Daha kalın
                  color: const Color(0xFF007AFF),
                  fontFeatures: const [
                    ui.FontFeature.enable('liga'),
                    ui.FontFeature.enable('calt'),
                  ],
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Anlam
            if (widget.word.anlam?.isNotEmpty == true) ...[
              Text(
                'Anlam',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.word.anlam!,
                style: TextStyle(
                  fontSize: 17,
                  color: isDarkMode ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E),
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Kök
            if (widget.word.koku?.isNotEmpty == true) ...[
              Text(
                'Kök',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.word.koku!,
                style: GoogleFonts.scheherazadeNew(
                  fontSize: 20, // Biraz büyüttüm
                  fontWeight: FontWeight.w700, // Kalın
                  color: const Color(0xFF007AFF),
                  fontFeatures: const [
                    ui.FontFeature.enable('liga'),
                    ui.FontFeature.enable('calt'),
                  ],
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
            ],
            
            // Dilbilgisel özellikler
            if (widget.word.dilbilgiselOzellikler?.isNotEmpty == true) ...[
              Text(
                'Dilbilgisel Özellikler',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.word.dilbilgiselOzellikler!.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? const Color(0xFF3A3A3C).withOpacity(0.8)
                          : const Color(0xFFE5E5EA).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode 
                            ? const Color(0xFF48484A)
                            : const Color(0xFFD1D1D6),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: TextStyle(
                        fontSize: 13, // Biraz küçülttüm
                        color: isDarkMode 
                            ? const Color(0xFFE5E5EA)
                            : const Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w500, // Orta kalınlık
                        letterSpacing: 0.2, // Estetik harf aralığı
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Örnek cümleler
            if (widget.word.ornekCumleler?.isNotEmpty == true) ...[
              Text(
                'Örnek Cümleler',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              ...widget.word.ornekCumleler!.map((example) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode 
                            ? const Color(0xFF48484A)
                            : const Color(0xFFE5E5EA),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Arapça cümle
                        if (example['arapcaCümle'] != null) ...[
                          Text(
                            example['arapcaCümle']!,
                            style: GoogleFonts.scheherazadeNew(
                              fontSize: 20,
                              color: isDarkMode 
                                  ? const Color(0xFFE5E5EA)
                                  : const Color(0xFF1C1C1E),
                              height: 1.6,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                ui.FontFeature.enable('liga'),
                                ui.FontFeature.enable('calt'),
                              ],
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Türkçe anlam
                        Text(
                          example['turkceAnlam'] ?? example['text'] ?? example['turkce'] ?? example.toString(),
                          style: TextStyle(
                            fontSize: 15,
                            color: isDarkMode 
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF6D6D70),
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
            
            // Fiil çekimleri
            if (widget.word.fiilCekimler?.isNotEmpty == true) ...[
              Text(
                'Fiil Çekimleri',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.word.fiilCekimler!.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? const Color(0xFF3A3A3C).withOpacity(0.8)
                          : const Color(0xFFE5E5EA).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDarkMode 
                            ? const Color(0xFF48484A)
                            : const Color(0xFFD1D1D6),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: TextStyle(
                        fontSize: 13, // Biraz küçülttüm
                        color: isDarkMode 
                            ? const Color(0xFFE5E5EA)
                            : const Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w500, // Orta kalınlık
                        letterSpacing: 0.2, // Estetik harf aralığı
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
} 