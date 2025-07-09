import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/turkce_analytics_service.dart';
import '../services/admob_service.dart';
import 'package:in_app_review/in_app_review.dart';

class InAppReviewWidget extends StatefulWidget {
  final VoidCallback onReviewSubmitted;
  final VoidCallback onClose;
  
  const InAppReviewWidget({
    super.key,
    required this.onReviewSubmitted,
    required this.onClose,
  });

  @override
  State<InAppReviewWidget> createState() => _InAppReviewWidgetState();
}

class _InAppReviewWidgetState extends State<InAppReviewWidget> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    // Değerlendirme dialog'u açıldığında reklam engellemesini aktif et
    AdMobService().setInAppActionFlag('review');
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    // Dialog kapatıldığında reklam engellemesini kaldır
    AdMobService().clearInAppActionFlag();
    super.dispose();
  }
  
  void _closeDialog() {
    // Dialog kapatılmadan önce reklam engellemesini kaldır
    AdMobService().clearInAppActionFlag();
    widget.onClose();
  }
  
  Future<void> _setRatedApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_rated_app', true);
  }
  
  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir puan seçin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    // Analytics event gönder
    await TurkceAnalyticsService.uygulamaDegerlendirmeAcildi();
    
    try {
      // Eğer 4 veya 5 yıldız verdiyse Google Play değerlendirme ekranını aç
      if (_rating >= 4) {
        final InAppReview inAppReview = InAppReview.instance;
        
        // Değerlendirme yapıldığını işaretle
        await _setRatedApp();
        
        // Değerlendirme isteğini göster
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
        } else {
          // Store sayfasını aç
          await inAppReview.openStoreListing(
            appStoreId: '', // iOS için gerekli değil
          );
        }
      } else {
        // Düşük puan - sadece teşekkür et ve kapat
        await _setRatedApp();
        
        // Geri bildirim varsa kaydet (gelecekte kullanılabilir)
        if (_commentController.text.isNotEmpty) {
          debugPrint('📝 Kullanıcı geri bildirimi ($_rating yıldız): ${_commentController.text}');
        }
      }
      
      if (mounted) {
        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_rating >= 4 
              ? 'Değerlendirmeniz için teşekkür ederiz! 🙏' 
              : 'Geri bildiriminiz için teşekkür ederiz!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reklam engellemesini kaldır (değerlendirme tamamlandı)
        AdMobService().clearInAppActionFlag();
        
        // Callback'i çağır
        widget.onReviewSubmitted();
      }
    } catch (e) {
      debugPrint('❌ Değerlendirme hatası: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bir hata oluştu, lütfen daha sonra tekrar deneyin'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Hata durumunda da reklam engellemesini kaldır
      AdMobService().clearInAppActionFlag();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve kapat butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uygulamayı Değerlendir',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                onPressed: _closeDialog,
                icon: Icon(
                  Icons.close,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Açıklama metni
          Text(
            'Kavaid uygulamasını kullandığınız için teşekkür ederiz! Deneyiminizi bizimle paylaşır mısınız?',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Yıldız puanlama
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = starIndex;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: starIndex <= _rating 
                        ? const Color(0xFFFFD700) 
                        : (isDarkMode ? Colors.white30 : Colors.black26),
                  ),
                ),
              );
            }),
          ),
          
          const SizedBox(height: 8),
          
          // Puan açıklaması
          if (_rating > 0)
            Text(
              _getRatingText(_rating),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _getRatingColor(_rating),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Yorum alanı
          TextField(
            controller: _commentController,
            maxLines: 4,
            maxLength: 500,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Yorumunuzu yazın (isteğe bağlı)',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.white38 : Colors.black38,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.white24 : Colors.black26,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.white24 : Colors.black26,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF007AFF),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDarkMode 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.black.withOpacity(0.03),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Gönder butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Değerlendirmeyi Gönder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Çok Kötü 😞';
      case 2:
        return 'Kötü 😐';
      case 3:
        return 'İdare Eder 🙂';
      case 4:
        return 'İyi 😊';
      case 5:
        return 'Mükemmel! 🤩';
      default:
        return '';
    }
  }
  
  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
} 