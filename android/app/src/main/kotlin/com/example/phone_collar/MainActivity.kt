package com.example.phone_collar

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.callhandling/methods"
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup method channel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "caller_id_channel")

        // Set method channel in CallHandlingService
        CallService.setMethodChannel(channel)

        // Setup method call handler
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "lookupCallerInfo" -> {
                    val phoneNumber = call.arguments as? String
                    if (phoneNumber != null) {
                        // Directly pass the result to the method channel
                        channel.invokeMethod(
                            "lookupCallerInfo",
                            phoneNumber,
                            object : MethodChannel.Result {
                                override fun success(callerInfo: Any?) {
                                    // Successfully retrieved caller info
                                    // Pass the result back to the original caller
                                    result.success(callerInfo)
                                }

                                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                                    // Handle error case
                                    result.error(errorCode, errorMessage, errorDetails)
                                }

                                override fun notImplemented() {
                                    // Handle not implemented case
                                    result.notImplemented()
                                }
                            }
                        )
                    } else {
                        result.error("INVALID_ARGUMENT", "Phone number is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}