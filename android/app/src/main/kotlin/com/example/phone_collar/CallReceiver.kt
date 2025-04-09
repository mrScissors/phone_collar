package com.example.phone_collar

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log

class CallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (TelephonyManager.ACTION_PHONE_STATE_CHANGED == intent.action) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            if (TelephonyManager.EXTRA_STATE_RINGING == state) {
                // Phone is ringing – start the CallService with incoming number
                val serviceIntent = Intent(context, CallService::class.java).apply {
                    putExtra("incoming_number", incomingNumber)
                }
                Log.d("CallReceiver", "Broadcast reciever Incoming phone number: $incomingNumber")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)  // Android 8+ requires foreground service
                } else {
                    context.startService(serviceIntent)
                }
            } else if (TelephonyManager.EXTRA_STATE_IDLE == state ||
                TelephonyManager.EXTRA_STATE_OFFHOOK == state) {
                // Call ended or answered – stop the service if running
                context.stopService(Intent(context, CallService::class.java))
            }
        }
    }
}
