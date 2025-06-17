import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import '../models/word_model.dart';
import '../services/saved_words_service.dart';

// Global expanded card controller
class ExpandedCardController {
  static _SearchResultCardState? _currentExpanded;
  
  static void setExpanded(_SearchResultCardState? card) {
    if (_currentExpanded != null && _currentExpanded != card && _currentExpanded!.mounted) {
      _currentExpanded!._collapseCard();
    }
    _currentExpanded = card;
  }
}

class SearchResultCard extends StatefulWidget {
  final WordModel word;
  final VoidCallback onTap;

  const SearchResultCard({
    super.key,
    required this.word,
    required this.onTap,
  });

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> with TickerProviderStateMixin {
  final SavedWordsService _savedWordsService = SavedWordsService();
  bool _isSaved = false;
  bool _isLoading = false;
  bool _isExpanded = false;
  
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // SavedWordsService'i dinle
    _savedWordsService.addListener(_updateSavedStatus);
    
    // İlk durum kontrolü
    _updateSavedStatus();
    
    // Animasyon controller'ı başlat - daha hızlı ve smooth
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    ));
  }

  @override
  void dispose() {
    // Listener'ı kaldır
    _savedWordsService.removeListener(_updateSavedStatus);
    _animationController.dispose();
    super.dispose();
  }

  void _updateSavedStatus() {
    if (!mounted) return;
    
    // Eğer initialize edilmemişse, async olarak yükle
    if (!_savedWordsService.isInitialized) {
      _initializeAndUpdate();
      return;
    }
    
    setState(() {
      _isSaved = _savedWordsService.isWordSavedSync(widget.word);
    });
  }
  
  Future<void> _initializeAndUpdate() async {
    if (!mounted) return;
    
    await _savedWordsService.initialize();
    
    if (mounted) {
      setState(() {
        _isSaved = _savedWordsService.isWordSavedSync(widget.word);
      });
    }
  }

  void _toggleExpanded() {
    if (!mounted) return;
    
    if (!_isExpanded) {
      // Diğer açık kartları kapat
      ExpandedCardController.setExpanded(this);
      if (mounted) {
        setState(() {
          _isExpanded = true;
        });
        _animationController.forward();
      }
    } else {
      _collapseCard();
    }
  }

  void _collapseCard() {
    if (!mounted) return;
    
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
      });
      _animationController.reverse();
    }
  }

  Future<void> _toggleSaved() async {
    if (_isLoading || !mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      bool success = false;
      
      if (_isSaved) {
        success = await _savedWordsService.removeWord(widget.word);
      } else {
        success = await _savedWordsService.saveWord(widget.word);
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
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode 
                ? const Color(0xFF48484A)
                : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.4)
                  : const Color(0xFF007AFF).withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 1,
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
        child: Column(
          children: [
            // Ana kart içeriği
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Harekeli Arapça kelime
                              Flexible(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.4,
                                  ),
                                  child: Text(
                                    widget.word.harekeliKelime?.isNotEmpty == true 
                                        ? widget.word.harekeliKelime! 
                                        : widget.word.kelime,
                                    style: GoogleFonts.scheherazadeNew(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                                      height: 1.4,
                                      fontFeatures: const [
                                        ui.FontFeature.enable('liga'),
                                        ui.FontFeature.enable('calt'),
                                      ],
                                    ),
                                    textDirection: TextDirection.rtl,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Kelime türü chip'i
                              Flexible(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: _buildWordInfoChips(isDarkMode),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Türkçe anlam
                          if (widget.word.anlam?.isNotEmpty == true) ...[
                            Text(
                              widget.word.anlam!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode 
                                    ? const Color(0xFF8E8E93) 
                                    : const Color(0xFF6D6D70),
                                height: 1.3,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: _isExpanded ? null : 2,
                              overflow: _isExpanded ? null : TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Kaydetme tuşu
                    InkWell(
                      onTap: _toggleSaved,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: _isLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDarkMode ? Colors.white54 : const Color(0xFF8E8E93),
                                ),
                              )
                            : Icon(
                                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                                color: _isSaved 
                                    ? const Color(0xFF007AFF)
                                    : (isDarkMode ? Colors.white54 : const Color(0xFF8E8E93)),
                                size: 16,
                              ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Açılır menü ikonu
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: isDarkMode ? Colors.white54 : const Color(0xFF8E8E93),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Genişleyebilir detay alanı
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 1.0,
                        color: isDarkMode 
                            ? const Color(0xFF48484A)
                            : const Color(0xFFD1D1D6),
                      ),
                      const SizedBox(height: 8),
                      
                      // Fiil çekimleri (yan yana, sadece varsa göster) - EN ÜSTTE
                      _buildConjugationRow(isDarkMode),
                      
                      // Örnek cümleler
                      _buildExampleSentences(isDarkMode),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWordInfoChips(bool isDarkMode) {
    final chips = <Widget>[];
    
    // Kelime türü (her zaman göster)
    if (widget.word.dilbilgiselOzellikler?.containsKey('tur') == true) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF007AFF), Color(0xFF0051D5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007AFF).withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          widget.word.dilbilgiselOzellikler!['tur'].toString(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ));
    }
    
    // Kök ve çoğul sadece expanded durumunda göster
    if (_isExpanded) {
      // Kök (sadece veri, etiket yok)
      if (widget.word.koku?.isNotEmpty == true) {
        chips.add(Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode 
                  ? const Color(0xFF48484A).withOpacity(0.5)
                  : const Color(0xFFE5E5EA),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'كök: ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode 
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF6D6D70),
                ),
              ),
              Flexible(
                child: Text(
                  widget.word.koku!,
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 12,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ));
      }
      
      // Çoğul (sadece veri, etiket yok)
      if (widget.word.dilbilgiselOzellikler?.containsKey('cogulForm') == true && 
          widget.word.dilbilgiselOzellikler!['cogulForm']?.toString().trim().isNotEmpty == true) {
        chips.add(Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode 
                  ? const Color(0xFF48484A).withOpacity(0.5)
                  : const Color(0xFFE5E5EA),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Çoğul: ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode 
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF6D6D70),
                ),
              ),
              Flexible(
                child: Text(
                  widget.word.dilbilgiselOzellikler!['cogulForm'].toString(),
                  style: GoogleFonts.scheherazadeNew(
                    fontSize: 12,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ));
      }
    }
    
    // Chip'ler arasına boşluk ekle
    final spacedChips = <Widget>[];
    for (int i = 0; i < chips.length; i++) {
      if (i > 0) spacedChips.add(const SizedBox(width: 6));
      spacedChips.add(chips[i]);
    }
    
    return spacedChips;
  }

  Widget _buildConjugationRow(bool isDarkMode) {
    if (widget.word.fiilCekimler?.isNotEmpty != true) return const SizedBox.shrink();
    
    final conjugations = <String, String>{};
    final fiilCekimler = widget.word.fiilCekimler!;
    
    // Sadece dolu olanları ekle
    if (fiilCekimler.containsKey('maziForm') && fiilCekimler['maziForm']?.toString().trim().isNotEmpty == true) {
      conjugations['Mazi'] = fiilCekimler['maziForm'].toString();
    }
    if (fiilCekimler.containsKey('muzariForm') && fiilCekimler['muzariForm']?.toString().trim().isNotEmpty == true) {
      conjugations['Müzari'] = fiilCekimler['muzariForm'].toString();
    }
    if (fiilCekimler.containsKey('mastarForm') && fiilCekimler['mastarForm']?.toString().trim().isNotEmpty == true) {
      conjugations['Mastar'] = fiilCekimler['mastarForm'].toString();
    }
    if (fiilCekimler.containsKey('emirForm') && fiilCekimler['emirForm']?.toString().trim().isNotEmpty == true) {
      conjugations['Emir'] = fiilCekimler['emirForm'].toString();
    }
    
    if (conjugations.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: conjugations.entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildConjugationChip(entry.key, entry.value, isDarkMode),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExampleSentences(bool isDarkMode) {
    if (widget.word.ornekCumleler?.isNotEmpty != true) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Container(
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
            borderRadius: BorderRadius.circular(8),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık - Kutu içinde üstte
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode 
                      ? const Color(0xFF007AFF).withOpacity(0.15)
                      : const Color(0xFF007AFF).withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: const Text(
                  'Örnek Cümleler',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // İçerik
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: widget.word.ornekCumleler!.take(2).map((example) {
                    final isLast = example == widget.word.ornekCumleler!.take(2).last;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (example['arapcaCümle'] != null) ...[
                          Text(
                            example['arapcaCümle'].toString(),
                            style: GoogleFonts.scheherazadeNew(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E),
                              height: 1.5,
                              fontFeatures: const [
                                ui.FontFeature.enable('liga'),
                                ui.FontFeature.enable('calt'),
                              ],
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          example['turkceAnlam']?.toString() ?? 
                          example['turkceCeviri']?.toString() ?? 
                          example['turkce']?.toString() ?? 
                          example.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode 
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF6D6D70),
                            height: 1.4,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  isDarkMode 
                                      ? const Color(0xFF48484A).withOpacity(0.3)
                                      : const Color(0xFFE5E5EA).withOpacity(0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConjugationChip(String title, String text, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Başlık
        Container(
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF007AFF),
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Arapça metin için kutu
        Container(
          width: double.infinity,
          height: 48,
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
                fontSize: 16,
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