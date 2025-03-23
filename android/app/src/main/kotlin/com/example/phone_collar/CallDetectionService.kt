package com.example.phone_collar

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.TelephonyManager
import android.app.Service
import android.os.IBinder
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Notification
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor.DartCallback
import io.flutter.FlutterInjector
import java.util.concurrent.atomic.AtomicBoolean

class CallDetectionService : Service() {
    private val TAG = "CallDetectionService"
    private val CHANNEL_ID = "call_detection_channel"
    private val NOTIFICATION_ID = 1001
    private val METHOD_CHANNEL_NAME = "com.example.yourapp/call_detection"

    private lateinit var callStateReceiver: CallStateReceiver
    private lateinit var methodChannel: MethodChannel
    private lateinit var flutterEngine: FlutterEngine
    private val serviceStarted = AtomicBoolean(false)

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")

        // Create notification channel for foreground service
        createNotificationChannel()

        // Start as foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification())

        // Initialize Flutter engine
        initializeFlutterEngine()

        // Register call state receiver
        callStateReceiver = CallStateReceiver()
        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        registerReceiver(callStateReceiver, filter)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Detection Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background service for detecting incoming calls"
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        // Create an intent that will open your app's main activity
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Call Detection Service")
            .setContentText("Monitoring incoming calls")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun initializeFlutterEngine() {
        // Get saved callback handle from SharedPreferences
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val callbackHandle = prefs.getLong("call_detection_callback_handle", 0)

        if (callbackHandle == 0L) {
            Log.e(TAG, "Fatal: No callback handle registered")
            stopSelf()
            return
        }

        // Initialize Flutter engine with callback
        flutterEngine = FlutterEngine(this)

        // Get the callback information
        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
        if (callbackInfo == null) {
            Log.e(TAG, "Fatal: Failed to find callback")
            stopSelf()
            return
        }

        // Get the Dart entrypoint
        val appBundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()

        // Set up the method channel for communication with Dart
        methodChannel = MethodChannel(flutterEngine.dartExecutor, METHOD_CHANNEL_NAME)

        // Start executing Dart in the background
        flutterEngine.dartExecutor.executeDartCallback(
            DartCallback(
                assets,
                appBundlePath,
                callbackInfo
            )
        )

        // Cache the Flutter engine
        FlutterEngineCache.getInstance().put("call_detection_engine", flutterEngine)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service onStartCommand")
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service onDestroy")
        try {
            unregisterReceiver(callStateReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }

        // Destroy Flutter engine
        flutterEngine.destroy()
    }

    inner class CallStateReceiver : BroadcastReceiver() {
        private var lastState = TelephonyManager.CALL_STATE_IDLE
        private var incomingNumber: String = ""

        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

            // Get the phone state and number
            val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val state = when (stateStr) {
                TelephonyManager.EXTRA_STATE_IDLE -> TelephonyManager.CALL_STATE_IDLE
                TelephonyManager.EXTRA_STATE_OFFHOOK -> TelephonyManager.CALL_STATE_OFFHOOK
                TelephonyManager.EXTRA_STATE_RINGING -> TelephonyManager.CALL_STATE_RINGING
                else -> TelephonyManager.CALL_STATE_IDLE
            }

            // Get the incoming number if available
            incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""

            onCallStateChanged(state, incomingNumber)
        }

        private fun onCallStateChanged(state: Int, number: String) {
            if (lastState == state) return

            when (state) {
                TelephonyManager.CALL_STATE_RINGING -> {
                    // Incoming call - launch Flutter UI
                    Log.d(TAG, "Incoming call from: $number")

                    // Send incoming call info to Flutter through method channel
                    try {
                        methodChannel.invokeMethod("incomingCall", mapOf(
                            "phoneNumber" to number,
                            "timestamp" to System.currentTimeMillis()
                        ))

                        // Launch the app to show the call screen
                        val launchIntent = Intent(this@CallDetectionService, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            putExtra("incoming_call", true)
                            putExtra("phone_number", number)
                        }
                        startActivity(launchIntent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending call data to Flutter: ${e.message}")
                    }
                }
                TelephonyManager.CALL_STATE_OFFHOOK -> {
                    // Call was answered
                    Log.d(TAG, "Call answered: $number")
                    try {
                        methodChannel.invokeMethod("callAnswered", mapOf(
                            "phoneNumber" to number
                        ))
                    } catch (e: Exception) {
                        Log.e(TAG, "Error sending answered event: ${e.message}")
                    }
                }
                TelephonyManager.CALL_STATE_IDLE -> {
                    // Call ended
                    if (lastState == TelephonyManager.CALL_STATE_RINGING) {
                        // Missed call
                        Log.d(TAG, "Missed call from: $number")
                        try {
                            methodChannel.invokeMethod("missedCall", mapOf(
                                "phoneNumber" to number
                            ))
                        } catch (e: Exception) {
                            Log.e(TAG, "Error sending missed call event: ${e.message}")
                        }
                    } else if (lastState == TelephonyManager.CALL_STATE_OFFHOOK) {
                        // Call ended
                        Log.d(TAG, "Call ended: $number")
                        try {
                            methodChannel.invokeMethod("callEnded", mapOf(
                                "phoneNumber" to number
                            ))
                        } catch (e: Exception) {
                            Log.e(TAG, "Error sending call ended event: ${e.message}")
                        }
                    }
                }
            }

            lastState = state
        }
    }
}