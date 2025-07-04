import 'package:flutter/material.dart';
import '../services/turkce_analytics_service.dart';

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
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
    
    // Analytics event gönder - artık türkçe event ismi kullanmıyoruz çünkü özel bir durum
    // Bu event internal bir widget event'i olduğu için genel "uygulamaDegerlendirmeAcildi" event'ini kullanıyoruz
    await TurkceAnalyticsService.uygulamaDegerlendirmeAcildi();
    
    // Biraz bekle (gerçek API çağrısı simülasyonu)
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      // Başarı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Değerlendirmeniz için teşekkür ederiz! 🙏'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Callback'i çağır
      widget.onReviewSubmitted();
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
                onPressed: widget.onClose,
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