import 'package:flutter/material.dart';
import 'package:kavaid/main.dart';
import 'package:kavaid/services/sync_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Başlatılıyor...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _statusMessage = 'Veritabanı senkronize ediliyor...\nBu işlem birkaç dakika sürebilir.';
      });

      // Veritabanı senkronizasyonunu başlat
      await SyncService().initializeLocalDatabase();

      // Senkronizasyon tamamlandığında ana ekrana geç
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const KavaidApp()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Bir hata oluştu: $e\nUygulama yine de başlatılıyor.';
        });
        // Hata durumunda bile birkaç saniye sonra devam et
        await Future.delayed(const Duration(seconds: 3));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const KavaidApp()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
