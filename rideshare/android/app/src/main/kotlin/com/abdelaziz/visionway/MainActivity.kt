package com.abdelaziz.visionway

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.abdelaziz.visionway/booking_notification"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showBookingNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val data =
                        args
                            ?.mapNotNull { (key, value) ->
                                val k = key?.toString() ?: return@mapNotNull null
                                val v = value?.toString() ?: return@mapNotNull null
                                k to v
                            }?.toMap()
                            ?: emptyMap()
                    BookingNotificationHelper.show(this, data)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BookingNotificationHelper.ensureChannel(this)
    }
}
