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
    
    return Container(
      key: ValueKey('word_card_${widget.word.kelime}'),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _toggleSaved,
                    borderRadius: BorderRadius.circular(20),
                    splashColor: const Color(0xFF007AFF).withOpacity(0.2),
                    highlightColor: const Color(0xFF007AFF).withOpacity(0.1),
                    child: Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isSaved 
                            ? const Color(0xFF007AFF).withOpacity(0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF007AFF).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: const Color(0xFF007AFF),
                        size: 24,
                      ),
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
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: 0.5,
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
            
            // Dilbilgisel özellikler
            if (widget.word.dilbilgiselOzellikler?.isNotEmpty == true) ...[
              Text(
                'Dilbilgisel Özellikler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.word.dilbilgiselOzellikler!.entries
                    .where((entry) => entry.key != 'cogulForm') // Çoğul bilgisini filtrele
                    .map((entry) {
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
                        fontSize: 13,
                        color: isDarkMode 
                            ? const Color(0xFFE5E5EA)
                            : const Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Kök ve Çoğul Bilgileri - Fiil çekimlerinden önce
            if ((widget.word.koku?.isNotEmpty == true) || 
                (widget.word.dilbilgiselOzellikler?.containsKey('cogulForm') == true && 
                 widget.word.dilbilgiselOzellikler!['cogulForm']?.toString().trim().isNotEmpty == true)) ...[
              Row(
                children: [
                  // Kök
                  if (widget.word.koku?.isNotEmpty == true) ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: isDarkMode 
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFF8F9FA),
                                    Color(0xFFF2F2F7),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                          color: isDarkMode ? const Color(0xFF2C2C2E) : null,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode 
                                ? const Color(0xFF48484A).withOpacity(0.5)
                                : const Color(0xFFE5E5EA),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode 
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Kök',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF007AFF),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.word.koku!,
                              style: GoogleFonts.scheherazadeNew(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode 
                                    ? const Color(0xFFE5E5EA)
                                    : const Color(0xFF1C1C1E),
                                fontFeatures: const [
                                  ui.FontFeature.enable('liga'),
                                  ui.FontFeature.enable('calt'),
                                ],
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if ((widget.word.koku?.isNotEmpty == true) && 
                      (widget.word.dilbilgiselOzellikler?.containsKey('cogulForm') == true && 
                       widget.word.dilbilgiselOzellikler!['cogulForm']?.toString().trim().isNotEmpty == true))
                    const SizedBox(width: 12),
                  // Çoğul
                  if (widget.word.dilbilgiselOzellikler?.containsKey('cogulForm') == true && 
                      widget.word.dilbilgiselOzellikler!['cogulForm']?.toString().trim().isNotEmpty == true) ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: isDarkMode 
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFF8F9FA),
                                    Color(0xFFF2F2F7),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                          color: isDarkMode ? const Color(0xFF2C2C2E) : null,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode 
                                ? const Color(0xFF48484A).withOpacity(0.5)
                                : const Color(0xFFE5E5EA),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode 
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Çoğul',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF007AFF),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.word.dilbilgiselOzellikler!['cogulForm'].toString(),
                              style: GoogleFonts.scheherazadeNew(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isDarkMode 
                                    ? const Color(0xFFE5E5EA)
                                    : const Color(0xFF1C1C1E),
                                fontFeatures: const [
                                  ui.FontFeature.enable('liga'),
                                  ui.FontFeature.enable('calt'),
                                ],
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Fiil çekimleri
            if (widget.word.fiilCekimler?.isNotEmpty == true) ...[
              Row(
                children: [
                  // Mazi
                  if (widget.word.fiilCekimler!.containsKey('maziForm') && 
                      widget.word.fiilCekimler!['maziForm']?.toString().trim().isNotEmpty == true) ...[
                    Expanded(
                      child: _buildConjugationBox(
                        'Mazi',
                        widget.word.fiilCekimler!['maziForm'].toString(),
                        isDarkMode,
                      ),
                    ),
                  ],
                  if (widget.word.fiilCekimler!.containsKey('maziForm') && 
                      widget.word.fiilCekimler!['maziForm']?.toString().trim().isNotEmpty == true &&
                      widget.word.fiilCekimler!.containsKey('muzariForm') && 
                      widget.word.fiilCekimler!['muzariForm']?.toString().trim().isNotEmpty == true)
                    const SizedBox(width: 8),
                  // Müzari
                  if (widget.word.fiilCekimler!.containsKey('muzariForm') && 
                      widget.word.fiilCekimler!['muzariForm']?.toString().trim().isNotEmpty == true) ...[
                    Expanded(
                      child: _buildConjugationBox(
                        'Müzari',
                        widget.word.fiilCekimler!['muzariForm'].toString(),
                        isDarkMode,
                      ),
                    ),
                  ],
                  if (widget.word.fiilCekimler!.values.where((v) => v?.toString().trim().isNotEmpty == true).length > 2 &&
                      widget.word.fiilCekimler!.containsKey('muzariForm') && 
                      widget.word.fiilCekimler!['muzariForm']?.toString().trim().isNotEmpty == true &&
                      widget.word.fiilCekimler!.containsKey('mastarForm') && 
                      widget.word.fiilCekimler!['mastarForm']?.toString().trim().isNotEmpty == true)
                    const SizedBox(width: 8),
                  // Mastar
                  if (widget.word.fiilCekimler!.containsKey('mastarForm') && 
                      widget.word.fiilCekimler!['mastarForm']?.toString().trim().isNotEmpty == true) ...[
                    Expanded(
                      child: _buildConjugationBox(
                        'Mastar',
                        widget.word.fiilCekimler!['mastarForm'].toString(),
                        isDarkMode,
                      ),
                    ),
                  ],
                  if (widget.word.fiilCekimler!.values.where((v) => v?.toString().trim().isNotEmpty == true).length > 3 &&
                      widget.word.fiilCekimler!.containsKey('mastarForm') && 
                      widget.word.fiilCekimler!['mastarForm']?.toString().trim().isNotEmpty == true &&
                      widget.word.fiilCekimler!.containsKey('emirForm') && 
                      widget.word.fiilCekimler!['emirForm']?.toString().trim().isNotEmpty == true)
                    const SizedBox(width: 8),
                  // Emir
                  if (widget.word.fiilCekimler!.containsKey('emirForm') && 
                      widget.word.fiilCekimler!['emirForm']?.toString().trim().isNotEmpty == true) ...[
                    Expanded(
                      child: _buildConjugationBox(
                        'Emir',
                        widget.word.fiilCekimler!['emirForm'].toString(),
                        isDarkMode,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Örnek cümleler
            if (widget.word.ornekCumleler?.isNotEmpty == true) ...[
              Text(
                'Örnek Cümleler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  letterSpacing: 0.5,
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
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
  
  Widget _buildConjugationBox(String title, String text, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Başlık
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF007AFF).withOpacity(0.15)
                : const Color(0xFF007AFF).withOpacity(0.08),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF007AFF),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Arapça metin için kutu
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: isDarkMode 
                ? null
                : const LinearGradient(
                    colors: [
                      Color(0xFFF8F9FA),
                      Color(0xFFF2F2F7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            color: isDarkMode ? const Color(0xFF2C2C2E) : null,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border.all(
              color: isDarkMode 
                  ? const Color(0xFF48484A).withOpacity(0.5)
                  : const Color(0xFFE5E5EA),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.scheherazadeNew(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E),
                height: 1.4,
                fontFeatures: const [
                  ui.FontFeature.enable('liga'),
                  ui.FontFeature.enable('calt'),
                ],
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ),
      ],
    );
  }
} 