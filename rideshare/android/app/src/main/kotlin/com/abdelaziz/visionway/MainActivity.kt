package com.abdelaziz.visionway

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val channelName = "com.abdelaziz.visionway/booking_notification"
    private var methodChannel: MethodChannel? = null
    private var pendingInstantOfferAction: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                channelName,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "showBookingNotification" -> {
                            val data = argsToStringMap(call.arguments)
                            BookingNotificationHelper.show(this, data)
                            result.success(true)
                        }
                        "showInstantOfferNotification" -> {
                            val data = argsToStringMap(call.arguments)
                            InstantOfferNotificationHelper.show(this, data)
                            result.success(true)
                        }
                        "cancelInstantOfferNotification" -> {
                            val offerId =
                                (call.arguments as? Map<*, *>)?.get("offerId")?.toString()
                                    ?: call.argument<String>("offerId")
                            if (offerId.isNullOrBlank()) {
                                result.error("bad_args", "offerId required", null)
                            } else {
                                InstantOfferNotificationHelper.cancel(this, offerId)
                                result.success(true)
                            }
                        }
                        "getPendingInstantOfferAction" -> {
                            val pending = pendingInstantOfferAction
                            pendingInstantOfferAction = null
                            result.success(pending)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BookingNotificationHelper.ensureChannel(this)
        captureInstantOfferIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureInstantOfferIntent(intent)
        flushPendingInstantOfferAction()
    }

    private fun captureInstantOfferIntent(intent: Intent?) {
        if (intent == null) return
        val action =
            intent.getStringExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ACTION)
                ?: return
        val offerId =
            intent.getStringExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ID)
                ?: return
        val payloadJson =
            intent.getStringExtra(InstantOfferNotificationHelper.EXTRA_PAYLOAD)
        val map = linkedMapOf(
            "action" to action,
            "offerId" to offerId,
            "type" to "instant_offer",
        )
        if (!payloadJson.isNullOrBlank()) {
            try {
                val obj = JSONObject(payloadJson)
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    map[key] = obj.optString(key)
                }
            } catch (_: Exception) {
                // keep action/offerId only
            }
        }
        pendingInstantOfferAction = map
        // Clear so we don't re-process on recreation without a new intent.
        intent.removeExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ACTION)
        intent.removeExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ID)
        intent.removeExtra(InstantOfferNotificationHelper.EXTRA_PAYLOAD)
    }

    private fun flushPendingInstantOfferAction() {
        val pending = pendingInstantOfferAction ?: return
        val channel = methodChannel ?: return
        pendingInstantOfferAction = null
        channel.invokeMethod("onInstantOfferAction", pending)
    }

    private fun argsToStringMap(arguments: Any?): Map<String, String> {
        val args = arguments as? Map<*, *> ?: return emptyMap()
        return args
            .mapNotNull { (key, value) ->
                val k = key?.toString() ?: return@mapNotNull null
                val v = value?.toString() ?: return@mapNotNull null
                k to v
            }.toMap()
    }
}
