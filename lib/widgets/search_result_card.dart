import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import '../models/word_model.dart';
import '../services/saved_words_service.dart';
import '../services/credits_service.dart';
import '../utils/performance_utils.dart';

// 🚀 PERFORMANCE: Font'ları cache'le
class _FontCache {
  static TextStyle? _arabicStyle;
  static TextStyle? _exampleArabicStyle;
  
  static TextStyle getArabicStyle() {
    _arabicStyle ??= GoogleFonts.scheherazadeNew(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.4,
      fontFeatures: const [
        ui.FontFeature.enable('liga'),
        ui.FontFeature.enable('calt'),
      ],
    );
    return _arabicStyle!;
  }
  
  static TextStyle getExampleArabicStyle() {
    _exampleArabicStyle ??= GoogleFonts.scheherazadeNew(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
      fontFeatures: const [
        ui.FontFeature.enable('liga'),
        ui.FontFeature.enable('calt'),
      ],
    );
    return _exampleArabicStyle!;
  }
}

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
  final VoidCallback? onExpand;

  const SearchResultCard({
    super.key,
    required this.word,
    required this.onTap,
    this.onExpand,
  });

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> with SingleTickerProviderStateMixin { // 🚀 PERFORMANCE: Single ticker
  final SavedWordsService _savedWordsService = SavedWordsService();
  final CreditsService _creditsService = CreditsService();
  late bool _isSaved;
  bool _isLoading = false;
  bool _isExpanded = false;
  
  // 🚀 PERFORMANCE: Animasyon controller'ı optimize et
  AnimationController? _animationController;
  Animation<double>? _expandAnimation;
  
  // 🚀 PERFORMANCE: Listener optimizasyonu
  bool _isListenerActive = false;

  @override
  void initState() {
    super.initState();
    
    // İlk durumu sync olarak belirle
    _isSaved = _savedWordsService.isWordSavedSync(widget.word);
    
    // 🚀 PERFORMANCE: Listener'ı delayed ekle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _savedWordsService.addListener(_updateSavedStatus);
        _isListenerActive = true;
      }
    });
  }

  @override
  void didUpdateWidget(SearchResultCard oldWidget) {
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
    _animationController?.dispose();
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
  
  // 🚀 PERFORMANCE: Animasyon controller'ı lazy initialize et
  void _initializeAnimation() {
    if (_animationController == null) {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 150), // 🚀 PERFORMANCE: Daha hızlı animasyon
        vsync: this,
      );
      
      _expandAnimation = CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeOutCubic, // 🚀 PERFORMANCE: Daha smooth curve
        reverseCurve: Curves.easeInCubic,
      );
    }
  }

  void _toggleExpanded() async {
    if (!mounted) return;
    
    // Klavyeyi kapat
    FocusScope.of(context).unfocus();
    
    // Arapça klavyeyi kapatmak için callback'i çağır
    widget.onExpand?.call();
    
    if (!_isExpanded) {
      // Önce hak kontrolü yap - animasyon başlatmadan önce
      final canOpen = await _creditsService.canOpenWord(widget.word.kelime);
      if (!canOpen) {
        // Hak yoksa hiç açılmasın
        if (mounted) {
          // Hak bitti uyarısı göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Kelime detayları görüntüleme hakkınız bitti. Premium üyelik alarak sınırsız erişim sağlayabilirsiniz.',
                style: TextStyle(fontSize: 12),
              ),
              backgroundColor: Colors.red.shade600,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Premium Al',
                textColor: Colors.white,
                onPressed: () {
                  // TODO: Premium satın alma sayfasına yönlendir
                },
              ),
            ),
          );
        }
        return; // Kartı açma
      }
      
      // Hak tüket
      final consumed = await _creditsService.consumeCredit(widget.word.kelime);
      if (!consumed) {
        // Hak tüketilemezse kartı açma
        return;
      }
      
      // 🚀 PERFORMANCE: Animasyonu lazy initialize et
      _initializeAnimation();
      
      // Hak var ve tüketildi, şimdi animasyonu başlat
      setState(() {
        _isExpanded = true;
      });
      _animationController!.forward();
      
      // Diğer açık kartları kapat
      ExpandedCardController.setExpanded(this);
    } else {
      _collapseCard();
    }
  }

  void _collapseCard() {
    if (!mounted || _animationController == null) return;
    
    if (_isExpanded) {
      _animationController!.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isExpanded = false;
          });
        }
      });
    }
  }

  Future<void> _toggleSaved() async {
    if (_isLoading || !mounted) return;
    
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
    
    // 🚀 PERFORMANCE: RepaintBoundary ve key optimizasyonu
    return RepaintBoundary(
      key: ValueKey('search_card_${widget.word.kelime}'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkMode 
                  ? const Color(0xFF48484A)
                  : const Color(0xFFD0D0D0),
              width: 0.8,
            ),
            // 🚀 PERFORMANCE: Shadow optimizasyonu
            boxShadow: (isDarkMode || !PerformanceUtils.enableShadows) ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 🚀 PERFORMANCE: Column boyutunu minimize et
            children: [
              // Ana kart içeriği
              _buildMainContent(isDarkMode),
              
              // 🚀 PERFORMANCE: Genişleyebilir detay alanını optimize et
              if (_isExpanded && _expandAnimation != null)
                SizeTransition(
                  sizeFactor: _expandAnimation!,
                  child: _buildExpandedContent(isDarkMode),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 🚀 PERFORMANCE: Ana içeriği ayrı widget'a al
  Widget _buildMainContent(bool isDarkMode) {
    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🚀 PERFORMANCE: Cache'lenmiş font stili
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.4,
                          ),
                          child: Text(
                            widget.word.harekeliKelime?.isNotEmpty == true 
                                ? widget.word.harekeliKelime! 
                                : widget.word.kelime,
                            style: _FontCache.getArabicStyle().copyWith(
                              color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
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
            _buildBookmarkButton(isDarkMode),
            // Açılır menü ikonu
            _buildExpandButton(isDarkMode),
          ],
        ),
      ),
    );
  }
  
  // 🚀 PERFORMANCE: Bookmark button'ı optimize et
  Widget _buildBookmarkButton(bool isDarkMode) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _toggleSaved,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          padding: const EdgeInsets.all(6),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                )
              : Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved 
                      ? const Color(0xFF007AFF)
                      : (isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF6D6D70)),
                  size: 20,
                ),
        ),
      ),
    );
  }
  
  // 🚀 PERFORMANCE: Expand button'ı optimize et
  Widget _buildExpandButton(bool isDarkMode) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleExpanded,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          padding: const EdgeInsets.all(4),
          child: AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 150), // 🚀 PERFORMANCE: Daha hızlı animasyon
            curve: Curves.easeInOut,
            child: Icon(
              Icons.expand_more,
              color: isDarkMode 
                  ? const Color(0xFF8E8E93) 
                  : const Color(0xFF6D6D70),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
  
  // 🚀 PERFORMANCE: Genişletilmiş içeriği optimize et
  Widget _buildExpandedContent(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1.0,
            color: isDarkMode 
                ? const Color(0xFF48484A)
                : const Color(0xFFD1D1D6),
          ),
          const SizedBox(height: 8),
          
          // Kök ve çoğul bilgileri (yan yana, sadece varsa göster)
          _buildRootAndPluralRow(isDarkMode),
          
          // Fiil çekimleri (yan yana, sadece varsa göster)
          _buildConjugationRow(isDarkMode),
          
          // Örnek cümleler
          _buildExampleSentences(isDarkMode),
        ],
      ),
    );
  }

  List<Widget> _buildWordInfoChips(bool isDarkMode) {
    final chips = <Widget>[];
    
    // Kelime türü (basit tasarım)
    if (widget.word.dilbilgiselOzellikler?.containsKey('tur') == true) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: isDarkMode 
              ? const Color(0xFF007AFF).withOpacity(0.2)
              : const Color(0xFF007AFF).withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDarkMode 
                ? const Color(0xFF007AFF).withOpacity(0.3)
                : const Color(0xFF007AFF).withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Text(
          widget.word.dilbilgiselOzellikler!['tur'].toString(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isDarkMode 
                ? const Color(0xFF007AFF)
                : const Color(0xFF007AFF).withOpacity(0.9),
            letterSpacing: 0.2,
          ),
        ),
      ));
    }
    
    return chips;
  }

  Widget _buildRootAndPluralRow(bool isDarkMode) {
    final hasRoot = widget.word.koku?.isNotEmpty == true;
    final hasPlural = widget.word.dilbilgiselOzellikler?.containsKey('cogulForm') == true && 
                      widget.word.dilbilgiselOzellikler!['cogulForm']?.toString().trim().isNotEmpty == true;
    
    if (!hasRoot && !hasPlural) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (hasRoot) ...[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode 
                        ? [
                            const Color(0xFF2C2C2E),
                            const Color(0xFF2C2C2E).withOpacity(0.8),
                          ]
                        : [
                            const Color(0xFFF8F9FA),
                            const Color(0xFFF2F3F5),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDarkMode 
                        ? const Color(0xFF48484A).withOpacity(0.5)
                        : const Color(0xFFD0D0D0),
                    width: 0.8,
                  ),
                ),
                child: Stack(
                  children: [
                    // Üst etiket
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                              ? const Color(0xFF8E8E93).withOpacity(0.2)
                              : const Color(0xFF007AFF).withOpacity(0.08),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(9),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Kök',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode 
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF007AFF).withOpacity(0.8),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    // Ana içerik
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 26, 8, 8),
                      child: Center(
                        child: Text(
                          widget.word.koku!,
                          style: GoogleFonts.scheherazadeNew(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode 
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
                            height: 1.2,
                            fontFeatures: const [
                              ui.FontFeature.enable('liga'),
                              ui.FontFeature.enable('calt'),
                            ],
                          ),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (hasRoot && hasPlural) const SizedBox(width: 8),
          if (hasPlural) ...[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode 
                        ? [
                            const Color(0xFF2C2C2E),
                            const Color(0xFF2C2C2E).withOpacity(0.8),
                          ]
                        : [
                            const Color(0xFFF8F9FA),
                            const Color(0xFFF2F3F5),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDarkMode 
                        ? const Color(0xFF48484A).withOpacity(0.5)
                        : const Color(0xFFD0D0D0),
                    width: 0.8,
                  ),
                ),
                child: Stack(
                  children: [
                    // Üst etiket
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                              ? const Color(0xFF8E8E93).withOpacity(0.2)
                              : const Color(0xFF007AFF).withOpacity(0.08),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(9),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Çoğul',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode 
                                ? const Color(0xFF8E8E93)
                                : const Color(0xFF007AFF).withOpacity(0.8),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    // Ana içerik
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 26, 8, 8),
                      child: Center(
                        child: Text(
                          widget.word.dilbilgiselOzellikler!['cogulForm'].toString(),
                          style: GoogleFonts.scheherazadeNew(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode 
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
                            height: 1.2,
                            fontFeatures: const [
                              ui.FontFeature.enable('liga'),
                              ui.FontFeature.enable('calt'),
                            ],
                          ),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
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
                     : const Color(0xFFD0D0D0),
                 width: 0.8,
               ),
             boxShadow: [
               BoxShadow(
                 color: isDarkMode 
                     ? Colors.black.withOpacity(0.2)
                     : Colors.black.withOpacity(0.04),
                 blurRadius: isDarkMode ? 4 : 6,
                 offset: Offset(0, isDarkMode ? 2 : 2),
                 spreadRadius: isDarkMode ? 0 : 0.3,
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
                          Container(
                            width: double.infinity,
                            child: Text(
                              example['arapcaCümle'].toString(),
                              style: _FontCache.getExampleArabicStyle().copyWith(
                                color: isDarkMode ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E),
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.left,
                            ),
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
                  : const Color(0xFFD0D0D0),
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

  Widget _buildInfoBox(String title, String content, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(10),
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
        color: isDarkMode 
            ? const Color(0xFF2C2C2E)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode 
              ? const Color(0xFF48484A).withOpacity(0.3)
              : const Color(0xFFD0D0D0),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.03),
            blurRadius: isDarkMode ? 4 : 5,
            offset: Offset(0, isDarkMode ? 2 : 1),
            spreadRadius: isDarkMode ? 0 : 0.2,
          ),
          if (!isDarkMode) ...[
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 1,
              offset: const Offset(0, -0.5),
              spreadRadius: 0,
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDarkMode 
                  ? const Color(0xFF007AFF)
                  : const Color(0xFF6D6D70),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.scheherazadeNew(
              fontSize: 16,
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
    );
  }
} 