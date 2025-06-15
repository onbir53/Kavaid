import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/word_model.dart';

class WordCard extends StatelessWidget {
  final WordModel word;

  const WordCard({
    super.key,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ana kelime
            Row(
              children: [
                Expanded(
                  child: Text(
                    word.kelime,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Favorilere ekleme işlemi
                  },
                  icon: const Icon(
                    Icons.bookmark_border,
                    color: Color(0xFF007AFF),
                    size: 28,
                  ),
                ),
              ],
            ),
            
            // Harekeli yazılış
            if (word.harekeliKelime?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                word.harekeliKelime!,
                style: GoogleFonts.amiri(
                  fontSize: 26, // Biraz büyüttüm
                  fontWeight: FontWeight.w700, // Daha kalın
                  color: const Color(0xFF007AFF),
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Anlam
            if (word.anlam?.isNotEmpty == true) ...[
              const Text(
                'Anlam',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              Text(
                word.anlam!,
                style: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF1C1C1E),
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Kök
            if (word.koku?.isNotEmpty == true) ...[
              const Text(
                'Kök',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              Text(
                word.koku!,
                style: GoogleFonts.amiri(
                  fontSize: 18, // Biraz büyüttüm
                  fontWeight: FontWeight.w600, // Kalın
                  color: const Color(0xFF007AFF),
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
            ],
            
            // Dilbilgisel özellikler
            if (word.dilbilgiselOzellikler?.isNotEmpty == true) ...[
              const Text(
                'Dilbilgisel Özellikler',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: word.dilbilgiselOzellikler!.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:                       Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(
                        fontSize: 13, // Biraz küçülttüm
                        color: Color(0xFF1C1C1E),
                        fontWeight: FontWeight.w500, // Orta kalınlık
                        letterSpacing: 0.2, // Estetik harf aralığı
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            // Örnek cümleler
            if (word.ornekCumleler?.isNotEmpty == true) ...[
              const Text(
                'Örnek Cümleler',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              ...word.ornekCumleler!.map((example) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE5E5EA),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      example['text'] ?? example['turkce'] ?? example.toString(),
                      style: const TextStyle(
                        fontSize: 16, // Biraz büyüttüm
                        color: Color(0xFF1C1C1E),
                        height: 1.6, // Daha rahat satır aralığı
                        fontWeight: FontWeight.w400, // Daha hafif
                        letterSpacing: 0.2, // Estetik harf aralığı
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
            
            // Fiil çekimleri
            if (word.fiilCekimler?.isNotEmpty == true) ...[
              const Text(
                'Fiil Çekimleri',
                style: TextStyle(
                  fontSize: 16, // Biraz küçülttüm
                  fontWeight: FontWeight.w500, // Daha hafif
                  color: Color(0xFF1C1C1E),
                  letterSpacing: 0.5, // Estetik harf aralığı
                ),
              ),
              const SizedBox(height: 8),
              ...word.fiilCekimler!.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1C1C1E),
                            fontFamily: 'Amiri',
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }
} 