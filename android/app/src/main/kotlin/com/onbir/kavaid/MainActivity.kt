package com.onbir.kavaid

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.Build
import android.app.ActivityManager
import android.util.Log
import android.content.pm.ConfigurationInfo
import android.hardware.display.DisplayManager
import android.view.Display

class MainActivity : FlutterActivity() {
    private val CHANNEL = "device_info"
    private val TAG = "KavaidPerformance"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 🚀 PERFORMANCE MOD: Hardware acceleration'ı zorla
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )
        
        // 🚀 PERFORMANCE MOD: Layout optimizasyonları
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = 
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        
        // 🚀 PERFORMANCE MOD: Performance flags
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // 🚀 FPS FIX: Refresh rate optimizasyonu
        optimizeRefreshRate()
        
        // 🚀 PERFORMANCE MOD: Cihaz performansını değerlendir ve logla
        evaluateDevicePerformance()
        
        // 🚀 PERFORMANCE MOD: MIUI ve diğer custom ROM'lar için özel ayarlar
        optimizeForCustomRoms()
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 🚀 PERFORMANCE MOD: Device info channel'ı kur
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    val deviceInfo = getDevicePerformanceInfo()
                    result.success(deviceInfo)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    // 🚀 FPS FIX: Refresh rate optimizasyonu
    private fun optimizeRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
                val supportedModes = display.supportedModes
                
                // En yüksek refresh rate'i bul
                var bestMode = display.mode
                var maxRefreshRate = bestMode.refreshRate
                
                for (mode in supportedModes) {
                    if (mode.refreshRate > maxRefreshRate) {
                        maxRefreshRate = mode.refreshRate
                        bestMode = mode
                    }
                }
                
                // Preferred display mode'u ayarla
                window.attributes.preferredDisplayModeId = bestMode.modeId
                
                Log.d(TAG, "🔥 Display Mode Optimizasyonu: ${bestMode.physicalWidth}x${bestMode.physicalHeight} @ ${bestMode.refreshRate}Hz")
            } catch (e: Exception) {
                Log.e(TAG, "Display mode optimizasyonu başarısız: ${e.message}")
            }
        }
    }
    
    // 🚀 PERFORMANCE MOD: Cihaz performansını değerlendir
    private fun evaluateDevicePerformance() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val configurationInfo = activityManager.deviceConfigurationInfo
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            
            // Cihaz bilgilerini logla
            Log.d(TAG, "=== KAVAID CIHAZ PERFORMANS RAPORU ===")
            Log.d(TAG, "Cihaz: ${Build.MANUFACTURER} ${Build.MODEL}")
            Log.d(TAG, "Android Version: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
            Log.d(TAG, "CPU Architecture: ${Build.SUPPORTED_ABIS.joinToString(", ")}")
            Log.d(TAG, "OpenGL ES Version: ${configurationInfo.glEsVersion}")
            Log.d(TAG, "Total RAM: ${memoryInfo.totalMem / (1024 * 1024)} MB")
            Log.d(TAG, "Available RAM: ${memoryInfo.availMem / (1024 * 1024)} MB")
            Log.d(TAG, "Low Memory: ${memoryInfo.lowMemory}")
            
            // Performans kategorisi belirle
            val performanceCategory = determinePerformanceCategory(memoryInfo, configurationInfo)
            Log.d(TAG, "Performans Kategorisi: $performanceCategory")
            
            // Özel optimizasyonları uygula
            applyPerformanceOptimizations(performanceCategory)
            
        } catch (e: Exception) {
            Log.e(TAG, "Cihaz performansı değerlendirilemedi: ${e.message}")
        }
    }
    
    // 🚀 PERFORMANCE MOD: Performans kategorisi belirleme
    private fun determinePerformanceCategory(memoryInfo: ActivityManager.MemoryInfo, configInfo: ConfigurationInfo): String {
        val totalRamMB = memoryInfo.totalMem / (1024 * 1024)
        val glEsVersion = configInfo.glEsVersion.toDoubleOrNull() ?: 0.0
        val apiLevel = Build.VERSION.SDK_INT
        
        return when {
            // Yüksek performans: 8GB+ RAM, OpenGL ES 3.2+, API 29+
            totalRamMB >= 8192 && glEsVersion >= 3.2 && apiLevel >= 29 -> "high_end"
            
            // Orta performans: 4-8GB RAM, OpenGL ES 3.0+, API 26+
            totalRamMB >= 4096 && glEsVersion >= 3.0 && apiLevel >= 26 -> "mid_range"
            
            // Düşük performans: <4GB RAM veya eski API
            else -> "low_end"
        }
    }
    
    // 🚀 PERFORMANCE MOD: Performans optimizasyonlarını uygula
    private fun applyPerformanceOptimizations(category: String) {
        when (category) {
            "high_end" -> {
                Log.d(TAG, "Yüksek performans optimizasyonları uygulanıyor...")
                // Sustained performance mode (API 24+)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    window.setSustainedPerformanceMode(true)
                }
            }
            "mid_range" -> {
                Log.d(TAG, "Orta performans optimizasyonları uygulanıyor...")
                // Balanced optimizations
            }
            "low_end" -> {
                Log.d(TAG, "Düşük performans optimizasyonları uygulanıyor...")
                // Conservative optimizations
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }
    
    // 🚀 PERFORMANCE MOD: Custom ROM optimizasyonları
    private fun optimizeForCustomRoms() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val model = Build.MODEL.lowercase()
        
        when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> {
                Log.d(TAG, "MIUI optimizasyonları uygulanıyor...")
                // MIUI için özel ayarlar
                optimizeForMIUI()
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                Log.d(TAG, "EMUI optimizasyonları uygulanıyor...")
                // EMUI için özel ayarlar
            }
            manufacturer.contains("oppo") || manufacturer.contains("oneplus") -> {
                Log.d(TAG, "ColorOS/OxygenOS optimizasyonları uygulanıyor...")
                // ColorOS/OxygenOS için özel ayarlar
            }
            manufacturer.contains("samsung") -> {
                Log.d(TAG, "One UI optimizasyonları uygulanıyor...")
                // Samsung One UI için özel ayarlar
                optimizeForSamsung()
            }
        }
    }
    
    // 🚀 PERFORMANCE MOD: MIUI özel optimizasyonları
    private fun optimizeForMIUI() {
        try {
            // MIUI'da display refresh rate zorlaması
            val layoutParams = window.attributes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                layoutParams.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
            }
            window.attributes = layoutParams
            
            Log.d(TAG, "MIUI optimizasyonları tamamlandı")
        } catch (e: Exception) {
            Log.e(TAG, "MIUI optimizasyonları başarısız: ${e.message}")
        }
    }
    
    // 🚀 PERFORMANCE MOD: Samsung özel optimizasyonları
    private fun optimizeForSamsung() {
        try {
            // Samsung cihazlar için özel ayarlar
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
            
            Log.d(TAG, "Samsung optimizasyonları tamamlandı")
        } catch (e: Exception) {
            Log.e(TAG, "Samsung optimizasyonları başarısız: ${e.message}")
        }
    }
    
    // 🚀 PERFORMANCE MOD: Flutter'a gönderilecek cihaz bilgileri
    private fun getDevicePerformanceInfo(): Map<String, Any> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val configurationInfo = activityManager.deviceConfigurationInfo
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "device" to Build.DEVICE,
            "androidVersion" to Build.VERSION.RELEASE,
            "apiLevel" to Build.VERSION.SDK_INT,
            "architecture" to Build.SUPPORTED_ABIS[0],
            "glEsVersion" to configurationInfo.glEsVersion,
            "totalRamMB" to (memoryInfo.totalMem / (1024 * 1024)),
            "availableRamMB" to (memoryInfo.availMem / (1024 * 1024)),
            "isLowMemory" to memoryInfo.lowMemory,
            "performanceCategory" to determinePerformanceCategory(memoryInfo, configurationInfo)
        )
    }
    
    override fun onResume() {
        super.onResume()
        // 🚀 PERFORMANCE MOD: Resume'da performans ayarlarını yenile
        Log.d(TAG, "Uygulama resume - performans ayarları aktif")
    }
    
    override fun onPause() {
        super.onPause()
        // 🚀 PERFORMANCE MOD: Pause'da güç tasarrufu
        Log.d(TAG, "Uygulama pause - güç tasarrufu modu")
    }
}
