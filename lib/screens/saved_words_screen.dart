import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/word_model.dart';
import '../services/saved_words_service.dart';
import '../widgets/word_card.dart';

class SavedWordsScreen extends StatefulWidget {
  final Function(VoidCallback)? onRefreshCallback;
  
  const SavedWordsScreen({
    super.key,
    this.onRefreshCallback,
  });

  @override
  State<SavedWordsScreen> createState() => _SavedWordsScreenState();
}

class _SavedWordsScreenState extends State<SavedWordsScreen> with AutomaticKeepAliveClientMixin {
  final SavedWordsService _savedWordsService = SavedWordsService();
  List<WordModel> _savedWords = [];
  bool _isLoading = true;
  WordModel? _selectedWord;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSavedWords();
    
    // SavedWordsService'i dinle
    _savedWordsService.addListener(_loadSavedWords);
    
    // Callback'i parent'a gönder
    if (widget.onRefreshCallback != null) {
      widget.onRefreshCallback!(_loadSavedWords);
    }
  }

  @override
  void dispose() {
    // Listener'ı kaldır
    _savedWordsService.removeListener(_loadSavedWords);
    super.dispose();
  }

  // Screen'e her gelindiğinde listeyi yenile
  void refreshList() {
    _loadSavedWords();
  }

  Future<void> _loadSavedWords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final savedWords = await _savedWordsService.getSavedWords();
      if (mounted) {
        setState(() {
          _savedWords = savedWords;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeWord(WordModel word) async {
    try {
      final success = await _savedWordsService.removeWord(word);
      if (success) {
        await _loadSavedWords(); // Listeyi yenile
      }
    } catch (e) {
      print('Kelime kaldırma hatası: $e');
    }
  }

  Future<void> _clearAllWords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tümünü Temizle'),
        content: const Text('Tüm kaydedilen kelimeleri silmek istediğinizden emin misiniz?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _savedWordsService.clearAllSavedWords();
        await _loadSavedWords();
      } catch (e) {
        print('Tüm kelimeleri temizleme hatası: $e');
      }
    }
  }

  void _selectWord(WordModel word) {
    setState(() {
      _selectedWord = word;
    });
  }

  void _goBackToList() {
    setState(() {
      _selectedWord = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_selectedWord != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kelime Detayı'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackToList,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80), // Banner alanında padding
          child: WordCard(word: _selectedWord!),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaydedilenler'),
        actions: [
          if (_savedWords.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAllWords,
              tooltip: 'Tümünü Temizle',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF007AFF),
              ),
            )
          : _savedWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: isDarkMode 
                            ? const Color(0xFF8E8E93)
                            : const Color(0xFF8E8E93),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz kaydedilen kelime yok',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDarkMode 
                              ? const Color(0xFF8E8E93)
                              : const Color(0xFF8E8E93),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 90), // Banner alanında padding
                  itemCount: _savedWords.length,
                  itemBuilder: (context, index) {
                    final word = _savedWords[index];
                    return _buildSavedWordCard(word, isDarkMode);
                  },
                ),
    );
  }

  Widget _buildSavedWordCard(WordModel word, bool isDarkMode) {
    return _SavedWordCardWidget(
      word: word,
      isDarkMode: isDarkMode,
      onRemove: () => _removeWord(word),
      onTap: () => _selectWord(word),
    );
  }
}

// Global expanded card controller for saved words
class SavedExpandedCardController {
  static _SavedWordCardWidgetState? _currentExpanded;
  
  static void setExpanded(_SavedWordCardWidgetState? card) {
    if (_currentExpanded != null && _currentExpanded != card && _currentExpanded!.mounted) {
      _currentExpanded!._collapseCard();
    }
    _currentExpanded = card;
  }
}

class _SavedWordCardWidget extends StatefulWidget {
  final WordModel word;
  final bool isDarkMode;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _SavedWordCardWidget({
    required this.word,
    required this.isDarkMode,
    required this.onRemove,
    required this.onTap,
  });

  @override
  State<_SavedWordCardWidget> createState() => _SavedWordCardWidgetState();
}

class _SavedWordCardWidgetState extends State<_SavedWordCardWidget> with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
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
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    if (!mounted) return;
    
    if (!_isExpanded) {
      // Diğer açık kartları kapat
      SavedExpandedCardController.setExpanded(this);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode 
              ? const Color(0xFF1C1C1E) 
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isDarkMode 
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDarkMode 
                  ? Colors.black.withOpacity(0.1)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            // Ana kart içeriği
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Arapça kelime
                              Text(
                                widget.word.harekeliKelime?.isNotEmpty == true 
                                    ? widget.word.harekeliKelime! 
                                    : widget.word.kelime,
                                style: GoogleFonts.notoNaskhArabic(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: widget.isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(width: 8),
                              // Kelime türü, kök ve çoğul
                              ..._buildWordInfoChips(),
                            ],
                          ),
                          const SizedBox(height: 5),
                          // Türkçe anlam
                          if (widget.word.anlam?.isNotEmpty == true) ...[
                            Text(
                              widget.word.anlam!,
                              style: TextStyle(
                                fontSize: 15,
                                color: widget.isDarkMode 
                                    ? const Color(0xFF8E8E93) 
                                    : const Color(0xFF6D6D70),
                                height: 1.3,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                              maxLines: _isExpanded ? null : 2,
                              overflow: _isExpanded ? null : TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Silme tuşu
                    InkWell(
                      onTap: widget.onRemove,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.bookmark,
                          color: const Color(0xFF007AFF),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Açılır menü ikonu
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: widget.isDarkMode ? Colors.white54 : const Color(0xFF8E8E93),
                        size: 18,
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 0.5,
                        color: widget.isDarkMode 
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFE5E5EA),
                      ),
                      const SizedBox(height: 12),
                      
                      // Fiil çekimleri (yan yana, sadece varsa göster) - EN ÜSTTE
                      _buildConjugationRow(),
                      
                      // Örnek cümleler
                      _buildExampleSentences(),
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

  List<Widget> _buildWordInfoChips() {
    final chips = <Widget>[];
    
    // Kelime türü (her zaman göster)
    if (widget.word.dilbilgiselOzellikler?.containsKey('tur') == true) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          widget.word.dilbilgiselOzellikler!['tur'].toString(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF007AFF),
          ),
        ),
      ));
    }
    
    // Kök ve çoğul sadece expanded durumunda göster
    if (_isExpanded) {
      // Kök (sadece veri, etiket yok) - Yeşil tema
      if (widget.word.koku?.isNotEmpty == true) {
        chips.add(Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: widget.isDarkMode 
                ? const Color(0xFF30D158).withOpacity(0.15)
                : const Color(0xFF34C759).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.word.koku!,
            style: GoogleFonts.notoNaskhArabic(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.isDarkMode 
                  ? const Color(0xFF30D158)
                  : const Color(0xFF34C759),
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
        ));
      }
      
      // Çoğul (sadece veri, etiket yok) - Turuncu tema
      if (widget.word.dilbilgiselOzellikler?.containsKey('cogulForm') == true && 
          widget.word.dilbilgiselOzellikler!['cogulForm']?.toString().trim().isNotEmpty == true) {
        chips.add(Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: widget.isDarkMode 
                ? const Color(0xFFFF9F0A).withOpacity(0.15)
                : const Color(0xFFFF9500).withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.word.dilbilgiselOzellikler!['cogulForm'].toString(),
            style: GoogleFonts.notoNaskhArabic(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: widget.isDarkMode 
                  ? const Color(0xFFFF9F0A)
                  : const Color(0xFFFF9500),
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
        ));
      }
    }
    
    // Chip'ler arasına boşluk ekle
    final spacedChips = <Widget>[];
    for (int i = 0; i < chips.length; i++) {
      if (i > 0) spacedChips.add(const SizedBox(width: 8));
      spacedChips.add(chips[i]);
    }
    
    return spacedChips;
  }

  Widget _buildConjugationRow() {
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: conjugations.entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildConjugationChip(entry.key, entry.value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExampleSentences() {
    if (widget.word.ornekCumleler?.isNotEmpty != true) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Örnek Cümleler',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: widget.isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
        const SizedBox(height: 8),
        ...widget.word.ornekCumleler!.take(2).map((example) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: widget.isDarkMode 
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: widget.isDarkMode 
                      ? const Color(0xFF3C3C3E)
                      : const Color(0xFFE5E5EA),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (example['arapcaCümle'] != null) ...[
                    Text(
                      example['arapcaCümle'].toString(),
                      style: GoogleFonts.notoNaskhArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                        height: 1.4,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    example['turkceAnlam']?.toString() ?? 
                    example['turkceCeviri']?.toString() ?? 
                    example['turkce']?.toString() ?? 
                    example.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: widget.isDarkMode 
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF6D6D70),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildConjugationChip(String title, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Başlık kutunun üstünde
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF007AFF),
          ),
        ),
        const SizedBox(height: 6),
        // Arapça metin için kutu
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: widget.isDarkMode 
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isDarkMode 
                  ? const Color(0xFF3C3C3E)
                  : const Color(0xFFE5E5EA),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.notoNaskhArabic(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: widget.isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                height: 1.2,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
} 