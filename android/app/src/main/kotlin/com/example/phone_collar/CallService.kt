package com.example.phone_collar

import android.Manifest
import android.app.Service
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.telecom.TelecomManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

class CallService : Service() {
    companion object {
        private var methodChannel: MethodChannel? = null
        private const val TAG = "CallService"

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
    }

    private lateinit var windowManager: WindowManager
    // Track all overlays in a list
    private val overlayViews = mutableListOf<View>()

    // Listen for call end to remove overlays
    private val callStateListener = object : PhoneStateListener() {
        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
            Log.d(TAG, "Call state changed to: $state")
            when (state) {
                TelephonyManager.CALL_STATE_IDLE -> {
                    // Call ended or rejected
                    Log.d(TAG, "Call ended, removing overlays")
                    removeAllOverlays()
                    stopSelf()
                }
                TelephonyManager.CALL_STATE_OFFHOOK -> {
                    // Call answered
                    Log.d(TAG, "Call answered, removing overlays")
                    removeAllOverlays()
                }
                // Keep overlays for CALL_STATE_RINGING
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Received intent with extras: ${intent?.extras}")
        val incomingNumber = intent?.getStringExtra("incoming_number") ?: "Unknown"
        Log.d(TAG, "Service started for number: $incomingNumber")

        // 1. Promote to foreground to avoid background execution limits.
        startForegroundWithNotification()

        // 2. Start listening for call state changes
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephony.listen(callStateListener, PhoneStateListener.LISTEN_CALL_STATE)

        // 3. Show the incoming call overlay UI.
        showCallOverlay(incomingNumber)

        return START_STICKY
    }

    private fun startForegroundWithNotification() {
        // Create a minimal notification for the foreground service
        val channelId = "call_service_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "Call Service",
                NotificationManager.IMPORTANCE_MIN
            )
            channel.description = "Handles incoming call popup"
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Incoming Call Service")
            .setContentText("Monitoring incoming calls")
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .build()
        startForeground(1, notification)
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun showCallOverlay(phoneNumber: String) {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        // Inflate a custom layout for the call popup
        val overlayView = LayoutInflater.from(this).inflate(R.layout.layout_call_popup, null)

        // Initialize UI elements in the overlay
        val numberText: TextView? = overlayView.findViewById(R.id.txtIncomingNumber)
        val nameText: TextView? = overlayView.findViewById(R.id.txtCallerName)
        val answerBtn: Button? = overlayView.findViewById(R.id.btnAnswer)
        val rejectBtn: Button? = overlayView.findViewById(R.id.btnReject)
        val dismissBtn: Button? = overlayView.findViewById(R.id.btnDismiss)

        numberText?.text = phoneNumber
        nameText?.text = "Identifying..."  // will update with caller ID name from Flutter

        // Set up Accept button click
        answerBtn?.setOnClickListener {
            Log.d(TAG, "Answer button clicked")
            answerCall()
            removeAllOverlays()
        }

        // Set up Reject button click
        rejectBtn?.setOnClickListener {
            Log.d(TAG, "Reject button clicked")
            endCall()
            removeAllOverlays()
        }

        // Set up Dismiss button click (hides overlay but keeps call ringing)
        dismissBtn?.setOnClickListener {
            Log.d(TAG, "Dismiss button clicked")
            dismissOverlay()
        }

        // Add swipe-to-dismiss functionality
        setupSwipeToDismiss(overlayView)

        // Overlay layout parameters for the window
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER

        try {
            // Add the view to the WindowManager to display the popup
            windowManager.addView(overlayView, params)
            overlayViews.add(overlayView)
            Log.d(TAG, "Overlay added successfully")

            // Query Flutter for caller ID name using MethodChannel
            queryCallerIdName(phoneNumber)
        } catch (e: Exception) {
            Log.e(TAG, "Error showing overlay", e)
        }
    }

    private fun setupSwipeToDismiss(overlayView: View) {
        var initialY = 0f
        var initialTouchY = 0f
        var isDragging = false
        val dismissThreshold = 200f // pixels to swipe before dismissing

        overlayView.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = view.y
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaY = event.rawY - initialTouchY

                    // Only allow upward swipes to dismiss
                    if (deltaY < 0) {
                        view.y = initialY + deltaY
                        isDragging = true
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val deltaY = event.rawY - initialTouchY

                    if (isDragging && abs(deltaY) > dismissThreshold) {
                        // Swipe threshold met, dismiss the overlay
                        Log.d(TAG, "Swipe to dismiss triggered")
                        dismissOverlay()
                    } else {
                        // Snap back to original position
                        view.animate().y(initialY).duration = 200
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun dismissOverlay() {
        Log.d(TAG, "Dismissing overlay (call continues ringing)")
        removeAllOverlays()
        // Note: We don't call stopSelf() here because the call is still active
        // The service will continue running and listening for call state changes
    }

    private fun removeAllOverlays() {
        Log.d(TAG, "removeAllOverlays() called")
        overlayViews.forEach { view ->
            try {
                windowManager.removeView(view)
            } catch (e: Exception) {
                Log.e(TAG, "Error removing overlay", e)
            }
        }
        overlayViews.clear()
        Log.d(TAG, "All overlays removed successfully")
    }

    /** Use TelecomManager to accept the ringing call (Android 8.0+) */
    private fun answerCall() {
        try {
            val tm = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Requires ANSWER_PHONE_CALLS permission granted
                if (ActivityCompat.checkSelfPermission(
                        this,
                        Manifest.permission.ANSWER_PHONE_CALLS
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    Log.e(TAG, "Missing ANSWER_PHONE_CALLS permission")
                    return
                }
                tm.acceptRingingCall()
                Log.d(TAG, "Call accepted via TelecomManager")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error answering call", e)
        }
    }

    /** Use TelecomManager to end/reject the call */
    @RequiresApi(Build.VERSION_CODES.P)
    private fun endCall() {
        try {
            val tm = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            if (ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ANSWER_PHONE_CALLS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.e(TAG, "Missing ANSWER_PHONE_CALLS permission")
                return
            }
            tm.endCall()
            Log.d(TAG, "Call ended via TelecomManager")

            // Force removal of overlays and stop service as backup
            removeAllOverlays()
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "Error ending call", e)
        }
    }

    private fun queryCallerIdName(phoneNumber: String) {
        Log.d(TAG, "Attempting to query caller ID for: $phoneNumber")

        if (methodChannel == null) {
            Log.e(TAG, "Method channel is null! Channel was not properly set.")
            overlayViews.lastOrNull()?.findViewById<TextView>(R.id.txtCallerName)?.text = "Channel Error"
            return
        }

        Log.d(TAG, "Invoking lookupCallerId method on channel")
        methodChannel?.invokeMethod("lookupCallerId", phoneNumber, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val callerName = result as? String ?: "Unknown"
                Log.d(TAG, "Success callback received with result: $callerName")
                overlayViews.lastOrNull()?.findViewById<TextView>(R.id.txtCallerName)?.text = callerName
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.e(TAG, "Error callback received: $errorCode - $errorMessage")
                overlayViews.lastOrNull()?.findViewById<TextView>(R.id.txtCallerName)?.text = "Error: $errorCode"
            }

            override fun notImplemented() {
                Log.e(TAG, "notImplemented callback received - method not found")
                overlayViews.lastOrNull()?.findViewById<TextView>(R.id.txtCallerName)?.text = "Not Implemented"
            }
        })
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        // Clean up: remove all overlays and unregister listener
        removeAllOverlays()
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephony.listen(callStateListener, PhoneStateListener.LISTEN_NONE)
    }
}