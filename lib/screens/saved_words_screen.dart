import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/word_model.dart';
import '../services/saved_words_service.dart';
import '../services/credits_service.dart';
import '../services/global_config_service.dart';
import '../widgets/word_card.dart';
import '../widgets/search_result_card.dart';
import '../services/turkce_analytics_service.dart';
import '../services/admob_service.dart';
import '../widgets/native_ad_widget.dart';

class SavedWordsScreen extends StatefulWidget {
  final double bottomPadding;
  final Function(VoidCallback) onRefreshCallback;
  
  const SavedWordsScreen({
    super.key,
    required this.bottomPadding,
    required this.onRefreshCallback,
  });

  @override
  State<SavedWordsScreen> createState() => _SavedWordsScreenState();
}

class _SavedWordsScreenState extends State<SavedWordsScreen> with AutomaticKeepAliveClientMixin {
  final SavedWordsService _savedWordsService = SavedWordsService();
  final CreditsService _creditsService = CreditsService();
  final GlobalConfigService _globalConfigService = GlobalConfigService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<WordModel> _savedWords = [];
  List<WordModel> _filteredWords = [];
  bool _isLoading = true;
  WordModel? _selectedWord;
  String _searchQuery = '';
  
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  // Timer? _adRefreshTimer; // KALDIRILDI

  // Gizli kod için
  static const String _secretCode = 'hxpruatksj7v';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSavedWords();
    _loadNativeAd();
    
    // SavedWordsService'i dinle
    _savedWordsService.addListener(_onSavedWordsChanged);
    
    // Callback'i parent'a gönder
    if (widget.onRefreshCallback != null) {
      widget.onRefreshCallback!(_loadSavedWords);
    }
    
    // Search controller değişikliklerini dinle
    _searchController.addListener(_filterWords);
    
    // Gizli kod kontrolü için listener ekle
    _searchController.addListener(_checkSecretCode);
  }

  @override
  void dispose() {
    // Listener'ı kaldır
    _savedWordsService.removeListener(_onSavedWordsChanged);
    _searchController.removeListener(_filterWords);
    _searchController.removeListener(_checkSecretCode);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _nativeAd?.dispose();
    // _adRefreshTimer?.cancel(); // KALDIRILDI
    super.dispose();
  }
  
  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: AdMobService.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('✅ [SavedWordsScreen] Native ad loaded successfully.');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
            // Yenileme fonksiyonu kaldırıldı.
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('❌ [SavedWordsScreen] Native ad failed to load: ${error.message}');
          ad.dispose();
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
    )..load();
  }

  // Gizli kod kontrolü
  void _checkSecretCode() {
    if (_searchController.text == _secretCode) {
      _togglePremiumFeature();
    }
  }
  
  // Abonelik özelliğini aç/kapa
  Future<void> _togglePremiumFeature() async {
    try {
      // Premium durumunu toggle et
      final isNowPremium = await _creditsService.togglePremiumStatus();
      
      // Arama kutusunu temizle
      _searchController.clear();
      _searchFocusNode.unfocus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isNowPremium ? Icons.workspace_premium : Icons.cancel,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  isNowPremium 
                      ? '✨ Reklamsız kullanım aktifleştirildi!'
                      : '👍 Reklamsız kullanım iptal edildi.',
                ),
              ],
            ),
            backgroundColor: isNowPremium ? Colors.green : Colors.blueGrey,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Premium toggle hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bir hata oluştu!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // SavedWordsService değişikliklerini dinle
  void _onSavedWordsChanged() {
    if (mounted) {
      setState(() {
        _savedWords = _savedWordsService.savedWords;
        _filteredWords = _savedWords;
      });
      // Arama filtresini yeniden uygula
      _filterWords();
    }
  }

  // Screen'e her gelindiğinde listeyi yenile
  void refreshList() {
    _loadSavedWords();
  }

  void _filterWords() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredWords = _savedWords;
      } else {
        _filteredWords = _savedWords.where((word) {
          return word.kelime.toLowerCase().contains(query) ||
                 (word.anlam?.toLowerCase().contains(query) ?? false) ||
                 (word.harekeliKelime?.toLowerCase().contains(query) ?? false);
        }).toList();
        
        // Analytics event'i gönder - sadece boş olmayan arama için
        if (query.isNotEmpty) {
          TurkceAnalyticsService.kayitliKelimelerdeArama(query, _filteredWords.length);
        }
      }
    });
  }

  Future<void> _loadSavedWords() async {
    // İlk yüklemede loading göster
    if (!_savedWordsService.isInitialized && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // İlk yüklemede veya initialize edilmemişse getSavedWords'ü çağır
      if (!_savedWordsService.isInitialized) {
        await _savedWordsService.getSavedWords();
      }
      
      // Cache'den oku
      if (mounted) {
        setState(() {
          _savedWords = _savedWordsService.savedWords;
          _filteredWords = _savedWords;
          _isLoading = false;
        });
        // Arama filtresini yeniden uygula
        _filterWords();
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
      builder: (context) => SafeArea(
        // 🔧 ANDROID 15 FIX: Dialog safe area padding
        child: AlertDialog(
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
      ),
    );

    if (confirmed == true) {
      try {
        await _savedWordsService.clearAllSavedWords();
        await _loadSavedWords();
        _searchController.clear();
      } catch (e) {
        print('Tüm kelimeleri temizleme hatası: $e');
      }
    }
  }

  void _selectWord(WordModel word) {
    // Analytics event'i gönder
    TurkceAnalyticsService.kelimeDetayiGoruntulendi(word.kelime);
    
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
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(8, 0, 8, widget.bottomPadding),
          child: WordCard(
            word: _selectedWord!,
            key: ValueKey('saved_word_detail_${_selectedWord!.kelime}'),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification) {
                if (_searchFocusNode.hasFocus) {
                  _searchFocusNode.unfocus();
                }
              }
              return false;
            },
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: <Widget>[
                SliverAppBar(
                  backgroundColor: isDarkMode 
                      ? const Color(0xFF1C1C1E)  // Dark tema için siyah
                      : const Color(0xFF007AFF), // Light tema için mavi
                  elevation: 0,
                  pinned: true,
                  floating: true,
                  snap: true,
                  toolbarHeight: 0,
                  expandedHeight: 0,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(56), // Ana ekran gibi
                    child: Container(
                      width: double.infinity,
                      color: isDarkMode 
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFF007AFF),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF2C2C2E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                            ],
                            border: Border.all(
                              color: isDarkMode
                                  ? const Color(0xFF48484A).withOpacity(0.3)
                                  : const Color(0xFFE5E5EA).withOpacity(0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: isDarkMode
                                      ? const Color(0xFF8E8E93)
                                      : const Color(0xFF8E8E93),
                                  size: 20,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF1C1C1E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Kaydedilen kelimelerde ara',
                                      hintStyle: TextStyle(
                                        color: isDarkMode
                                            ? const Color(0xFF8E8E93).withOpacity(0.8)
                                            : const Color(0xFF8E8E93),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (value) {
                                      // Enter'a basıldığında gizli kodu kontrol et
                                      if (value == _secretCode) {
                                        _togglePremiumFeature();
                                      }
                                    },
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        _searchController.clear();
                                      },
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Colors.white.withOpacity(0.08)
                                              : const Color(0xFF8E8E93).withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.clear,
                                          color: isDarkMode
                                              ? const Color(0xFF8E8E93).withOpacity(0.8)
                                              : const Color(0xFF8E8E93),
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_savedWords.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _clearAllWords,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF3B30).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          'Temizle',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFFF3B30),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      gradient: isDarkMode
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF007AFF),
                                Color(0xFF0051D5),
                              ],
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.3)
                              : const Color(0xFF007AFF).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // İçerik
                _buildContentSliver(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSliver() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF007AFF),
          ),
        ),
      );
    }

    if (_savedWords.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark_border,
                  size: 40,
                  color: Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz kaydedilen kelime yok',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode 
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF6D6D70),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredWords.isEmpty && _searchQuery.isNotEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF8E8E93).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off,
                  size: 40,
                  color: Color(0xFF8E8E93),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sonuç bulunamadı',
                style: TextStyle(
                  fontSize: 18,
                  color: isDarkMode 
                      ? Colors.white
                      : const Color(0xFF1C1C1E),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"$_searchQuery" için arama sonucu yok',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode 
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Yer tutucu mantığı kaldırıldı, reklam sadece yüklüyse gösterilecek.
    int totalAds = (_isAdLoaded && _nativeAd != null && _filteredWords.length >= 3) ? 1 : 0;
    const int adPosition = 3;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, widget.bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (totalAds == 1 && index == adPosition) {
              return NativeAdWidget(ad: _nativeAd!);
            }

            final itemIndex = (totalAds == 1 && index > adPosition) ? index - 1 : index;
            if (itemIndex >= _filteredWords.length) return const SizedBox.shrink();

            final word = _filteredWords[itemIndex];
            return SearchResultCard(
              word: word,
              onTap: () => _selectWord(word),
              onExpand: () => FocusScope.of(context).unfocus(),
            );
          },
          childCount: _filteredWords.length + totalAds,
        ),
      ),
    );
  }
} 