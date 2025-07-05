import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/word_model.dart';
import '../services/firebase_service.dart';
import '../services/credits_service.dart';
import 'suggestion_card.dart';

class RecentWordsSection extends StatefulWidget {
  const RecentWordsSection({super.key});

  @override
  State<RecentWordsSection> createState() => _RecentWordsSectionState();
}

class _RecentWordsSectionState extends State<RecentWordsSection> {
  final FirebaseService _firebaseService = FirebaseService();
  final CreditsService _creditsService = CreditsService();
  List<WordModel> _recentWords = [];
  int _totalWordCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentWords();
  }

  Future<void> _loadRecentWords() async {
    try {
      final words = await _firebaseService.getRecentWords(limit: 10);
      final count = await _firebaseService.getTotalWordCount();
      
      if (mounted) {
        setState(() {
          _recentWords = words;
          _totalWordCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshWords() async {
    setState(() {
      _isLoading = true;
    });
    await _loadRecentWords();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refreshWords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(theme),
            const SizedBox(height: 20),
            _buildStatsCard(theme),
            const SizedBox(height: 20),
            _buildRecentWordsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: theme.colorScheme.primaryContainer,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kavaid\'e Hoş Geldiniz!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'AI destekli Arapça-Türkçe sözlük uygulamanız. Arama çubuğuna kelime yazarak başlayın!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildFeatureChip(theme, Icons.psychology, 'AI Destekli'),
                const SizedBox(width: 8),
                _buildFeatureChip(theme, Icons.cloud, 'Firebase'),
                const SizedBox(width: 8),
                _buildFeatureChip(theme, Icons.auto_awesome, 'Akıllı'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onPrimaryContainer.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.library_books,
                color: theme.colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sözlük İstatistikleri',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toplam $_totalWordCount kelime kayıtlı',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshWords,
                tooltip: 'Yenile',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentWordsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Son Eklenen Kelimeler',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_isLoading)
          _buildLoadingState(theme)
        else if (_recentWords.isEmpty)
          _buildEmptyState(theme)
        else
          _buildWordsList(),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          SpinKitFadingCircle(
            color: theme.colorScheme.primary,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'Kelimeler yükleniyor...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz Kelime Yok',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk kelimelerinizi aramaya başlayın!\nBulunan kelimeler otomatik olarak sözlüğe eklenecek.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordsList() {
    return Column(
      children: _recentWords.map((word) {
        return SuggestionCard(
          word: word,
          onTap: () {
            // Parent widget'a kelime seçildi sinyali gönder
            // Bu durumda basit bir navigator kullanabiliriz
            // Veya callback pattern ile parent'a haber verebiliriz
            _showWordDetails(word);
          },
        );
      }).toList(),
    );
  }

  void _showWordDetails(WordModel word) async {
    // Önce hak kontrolü yap
    final canOpen = await _creditsService.canOpenWord(word.kelime);
    
    if (!canOpen) {
      // Hak yetersiz - Dialog göster
      _showNoCreditsDialog();
      return;
    }
    
    // Hak düşür
    final success = await _creditsService.consumeCredit(word.kelime);
    
    if (!success) {
      _showNoCreditsDialog();
      return;
    }
    
    // Kelime detaylarını normal dialog ile göster
    showDialog(
      context: context,
      builder: (context) => SafeArea(
        // 🔧 ANDROID 15 FIX: Dialog safe area padding
        child: AlertDialog(
          title: Text(word.kelime),
          content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (word.harekeliKelime != null && word.harekeliKelime!.isNotEmpty) ...[
                Text(
                  'Harekeli Yazılış:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  word.harekeliKelime!,
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'NotoSansArabic',
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
              ],
              if (word.anlam != null && word.anlam!.isNotEmpty) ...[
                Text(
                  'Anlam:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(word.anlam!),
                const SizedBox(height: 12),
              ],
              if (word.koku != null && word.koku!.isNotEmpty) ...[
                Text(
                  'Kök:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  word.koku!,
                  style: TextStyle(fontSize: 16),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
        ),
      ),
    );
  }
  
  void _showNoCreditsDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SafeArea(
        // 🔧 ANDROID 15 FIX: Dialog safe area padding
        child: AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.credit_card_off,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Hakkınız Bitti',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _creditsService.hasInitialCredits
                  ? '50 ücretsiz hakkınız bitmiştir. Günlük yenilenen 5 hak ile devam edebilir veya Premium\'a yükselterek sınırsız erişim kazanabilirsiniz.'
                  : 'Günlük 5 hakkınız bitmiştir. Yarın saat 00:00\'da yeni haklarınız yüklenecektir.',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.8)
                    : Colors.black.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF007AFF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Premium üyelik ile sınırsız kelime detaylarına ve reklamsız deneyime erişebilirsiniz.',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF007AFF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Kapat',
              style: TextStyle(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Ana widget'a profil sekmesine geçmesi için sinyal gönder
              // Bu kısım parent widget'tan callback ile çözülmeli
              // Şimdilik basit bir çözüm kullanıyoruz
              DefaultTabController.of(context).animateTo(2); // Profil sekmesi
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
            ),
            child: const Text('Premium\'a Bak'),
          ),
        ],
        ),
      ),
    );
  }
} 