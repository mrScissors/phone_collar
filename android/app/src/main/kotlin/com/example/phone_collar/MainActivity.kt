package com.example.phone_collar

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import android.content.Intent
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager

class MainActivity : FlutterActivity() {

    private val eventChannelName = "com.example.phone_collar/incomingCallStream"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Existing EventChannel code (for streams inside your running Flutter app):
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                var phoneStateListener: PhoneStateListener? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
                    phoneStateListener = object : PhoneStateListener() {
                        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                            if (state == TelephonyManager.CALL_STATE_RINGING && phoneNumber != null) {
                                events?.success(phoneNumber)
                            }
                        }
                    }
                    telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
                }

                override fun onCancel(arguments: Any?) {
                    val telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
                    phoneStateListener?.let {
                        telephonyManager.listen(it, PhoneStateListener.LISTEN_NONE)
                    }
                }
            })
    }

}
