package com.example.calligro_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.app.Activity.ScreenCaptureCallback
import io.flutter.embedding.android.FlutterActivity
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.database.ContentObserver
import android.net.Uri
import android.provider.MediaStore
import android.os.Handler
import android.os.Looper

import android.util.Log
import android.widget.Toast

class MainActivity : FlutterActivity() {
    private val TAG = "CalligroSecurity"
    private val CHANNEL = "com.calligro.app/security"
    private var securityChannel: MethodChannel? = null
    private var screenshotObserver: ContentObserver? = null
    private var screenCaptureCallback: Any? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        securityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        securityChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    Log.d(TAG, "🔓 Security: Enabling FLAG_SECURE")
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    startScreenshotDetection()
                    result.success(true)
                }
                "disableSecure" -> {
                    Log.d(TAG, "🔒 Security: Disabling FLAG_SECURE")
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    stopScreenshotDetection()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startScreenshotDetection() {
        // 1. Official API for Android 14+ (UPSIDE_DOWN_CAKE)
        if (Build.VERSION.SDK_INT >= 34) {
            if (screenCaptureCallback == null) {
                Log.d(TAG, "🛡️ Registering ScreenCaptureCallback (API 34+)")
                val callback = ScreenCaptureCallback {
                    Log.d(TAG, "📸 Screenshot attempt detected via Official API")
                    runOnUiThread { 
                        Toast.makeText(this@MainActivity, "Security: Official API Detected Capture", Toast.LENGTH_SHORT).show()
                        securityChannel?.invokeMethod("onScreenshotTaken", null) 
                    }
                }
                registerScreenCaptureCallback(mainExecutor, callback)
                screenCaptureCallback = callback
            }
        }

        // 2. Fallback MediaStore observation
        if (screenshotObserver == null) {
            Log.d(TAG, "🛡️ Registering MediaStore Observer")
            screenshotObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    super.onChange(selfChange, uri)
                    Log.d(TAG, "📸 Potential screenshot detected via MediaStore change")
                    runOnUiThread { 
                        Toast.makeText(this@MainActivity, "Security: MediaStore Change Detected", Toast.LENGTH_SHORT).show()
                        securityChannel?.invokeMethod("onScreenshotTaken", null) 
                    }
                }
            }
            contentResolver.registerContentObserver(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, screenshotObserver!!)
            contentResolver.registerContentObserver(MediaStore.Images.Media.INTERNAL_CONTENT_URI, true, screenshotObserver!!)
        }
    }

    private fun stopScreenshotDetection() {
        if (Build.VERSION.SDK_INT >= 34) {
            screenCaptureCallback?.let {
                Log.d(TAG, "🛡️ Unregistering ScreenCaptureCallback")
                unregisterScreenCaptureCallback(it as ScreenCaptureCallback)
                screenCaptureCallback = null
            }
        }

        screenshotObserver?.let {
            Log.d(TAG, "🛡️ Unregistering MediaStore Observer")
            contentResolver.unregisterContentObserver(it)
            screenshotObserver = null
        }
    }

    // 💡 Heuristic: On some devices FLAG_SECURE prevents standard signals,
    // but the system screenshot UI will momentarily cause us to lose focus.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // If we are currently 'protecting' and lose focus, it might be a screenshot attempt
        if (!hasFocus && screenshotObserver != null) {
            Log.d(TAG, "🛡️ Heuristic: Focus lost while protected - potential screenshot UI")
            Toast.makeText(this, "Security: Focus Lost (Heuristic)", Toast.LENGTH_SHORT).show()
            
            // Reduced delay for faster detection
            Handler(Looper.getMainLooper()).postDelayed({
                if (screenshotObserver != null) {
                    securityChannel?.invokeMethod("onScreenshotTaken", null)
                }
            }, 400)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "calligro_alerts",
                "Calligro Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Important notifications for Calligro users"
            }
            
            val notificationManager: NotificationManager =
                getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
