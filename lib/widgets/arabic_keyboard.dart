import 'package:flutter/material.dart';

class ArabicKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onClose;

  const ArabicKeyboard({
    super.key,
    required this.controller,
    this.onClose,
  });

  // Standart Arapça klavye düzeni (görüntüdeki gibi)
  static const List<List<String>> _arabicKeys = [
    // İlk sıra
    ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج'],
    // İkinci sıra  
    ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك', 'ط'],
    // Üçüncü sıra
    ['ذ', 'ء', 'و', 'ر', 'ى', 'ة', 'ي', 'ز', 'ظ', 'د'],
  ];

  // Hareke satırı - üstte ayrı
  static const List<String> _diacritics = [
    'َ', // Fetha
    'ِ', // Kesra  
    'ُ', // Damma
    'ْ', // Sukun
    'ّ', // Şedde
    'ً', // Tenvin Fetha
    'ٍ', // Tenvin Kesra
    'ٌ', // Tenvin Damma
  ];

  void _insertText(String text) {
    final currentText = controller.text;
    final selection = controller.selection;
    
    if (selection.isValid) {
      final newText = currentText.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + text.length,
        ),
      );
    } else {
      controller.text = currentText + text;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  void _backspace() {
    final currentText = controller.text;
    final selection = controller.selection;
    
    if (selection.isValid && selection.start > 0) {
      final newText = currentText.replaceRange(
        selection.start - 1,
        selection.end,
        '',
      );
      
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start - 1,
        ),
      );
    }
  }

  void _addSpace() {
    _insertText(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFF2F2F7),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimal başlık
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ع',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(
                    Icons.keyboard_hide,
                    size: 20,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          
          // Hareke satırı - en üstte
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _diacritics.map((diacritic) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: _buildKey(diacritic, isDiacritic: true),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Ana harfler
          ..._arabicKeys.map((row) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((letter) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.5),
                      child: _buildKey(letter),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
          
          // Son satır: Boşluk ve kontrol butonları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: _buildKey('⌫', isBackspace: true),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 4,
                  child: _buildKey(' ', isSpace: true),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildReturnKey(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String text, {bool isDiacritic = false, bool isBackspace = false, bool isSpace = false}) {
    return GestureDetector(
      onTap: () {
        if (isBackspace) {
          _backspace();
        } else if (isSpace) {
          _addSpace();
        } else {
          _insertText(text);
        }
      },
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isDiacritic 
              ? const Color(0xFFE3F2FD)
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDiacritic 
                ? const Color(0xFF007AFF).withOpacity(0.3)
                : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Center(
          child: isBackspace
              ? const Icon(
                  Icons.backspace_outlined,
                  size: 18,
                  color: Color(0xFF8E8E93),
                )
              : Text(
                  isSpace ? 'Space' : text,
                  style: TextStyle(
                    fontSize: isSpace ? 12 : 18,
                    fontWeight: FontWeight.w400,
                    color: isDiacritic 
                        ? const Color(0xFF007AFF)
                        : const Color(0xFF1C1C1E),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    String? text,
    IconData? icon,
    required VoidCallback onPressed,
    bool isSearch = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isSearch 
              ? const Color(0xFF007AFF)
              : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  color: isSearch ? Colors.white : const Color(0xFF8E8E93),
                  size: 18,
                )
              : Text(
                  text!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSearch ? Colors.white : const Color(0xFF8E8E93),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildReturnKey() {
    return _buildSpecialKey(
      text: 'Ara',
      onPressed: () {
        if (onClose != null) {
          onClose!();
        }
      },
      isSearch: true,
    );
  }
} 