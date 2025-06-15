import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/word_model.dart';
import '../services/saved_words_service.dart';

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

class _SearchResultCardState extends State<SearchResultCard> {
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
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDarkMode 
                ? const Color(0xFF1C1C1E) 
                : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDarkMode 
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFE5E5EA),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode 
                    ? Colors.black.withOpacity(0.15)
                    : Colors.black.withOpacity(0.02),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Harekeli Arapça kelime (öncelik harekeli kelimeye)
                        Text(
                          widget.word.harekeliKelime?.isNotEmpty == true 
                              ? widget.word.harekeliKelime! 
                              : widget.word.kelime,
                          style: GoogleFonts.amiri(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(width: 8),
                        // Kelime türü chip'i - JSON yapısından dilbilgiselOzellikler.tur
                        if (widget.word.dilbilgiselOzellikler?.containsKey('tur') == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.word.dilbilgiselOzellikler!['tur'].toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Türkçe anlam
                    if (widget.word.anlam?.isNotEmpty == true) ...[
                      Text(
                        widget.word.anlam!,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode 
                              ? const Color(0xFF8E8E93) 
                              : const Color(0xFF6D6D70),
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Kaydetme tuşu
              InkWell(
                onTap: _toggleSaved,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
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
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 4),
              // Açılır menü ikonu
              Icon(
                Icons.keyboard_arrow_down,
                color: isDarkMode ? Colors.white54 : const Color(0xFF8E8E93),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 