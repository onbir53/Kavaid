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
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
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
          ...List.generate(_arabicKeys.length, (rowIndex) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _arabicKeys[rowIndex].map((key) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.5),
                      child: _buildKey(key),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
          
          // Alt satır - minimal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              children: [
                // Backspace
                Expanded(
                  flex: 2,
                  child: _buildSpecialKey(
                    icon: Icons.backspace_outlined,
                    onPressed: _backspace,
                  ),
                ),
                const SizedBox(width: 2),
                // Boşluk
                Expanded(
                  flex: 5,
                  child: _buildSpecialKey(
                    text: 'Boşluk',
                    onPressed: _addSpace,
                  ),
                ),
                const SizedBox(width: 2),
                // Enter/Ara
                Expanded(
                  flex: 2,
                  child: _buildSpecialKey(
                    text: 'Ara',
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                    },
                    isSearch: true,
                  ),
                ),
              ],
            ),
          ),
          
          // Minimal padding
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildKey(String text, {bool isDiacritic = false}) {
    return GestureDetector(
      onTap: () => _insertText(text),
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
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
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
} 