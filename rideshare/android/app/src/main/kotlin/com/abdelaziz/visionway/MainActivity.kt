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

    /** Payload of a tapped rich notification (e.g. a booking request). */
    private var pendingNotificationTap: Map<String, String>? = null

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
                        "cancelBookingNotification" -> {
                            val bookingId = (call.arguments as? Map<*, *>)?.get("bookingId")?.toString()
                            if (!bookingId.isNullOrBlank()) {
                                BookingNotificationHelper.cancel(this, bookingId)
                            }
                            result.success(true)
                        }
                        "startInstantOfferRing" -> {
                            val args = call.arguments as? Map<*, *>
                            val offerId = args?.get("offerId")?.toString()
                            val untilMs = (args?.get("untilMs") as? Number)?.toLong()
                            if (offerId.isNullOrBlank() || untilMs == null) {
                                result.error("bad_args", "offerId and untilMs required", null)
                            } else {
                                InstantOfferRinger.start(this, offerId, untilMs)
                                result.success(true)
                            }
                        }
                        "stopInstantOfferRing" -> {
                            val offerId = (call.arguments as? Map<*, *>)?.get("offerId")?.toString()
                            InstantOfferRinger.stop(offerId)
                            result.success(true)
                        }
                        "getPendingInstantOfferAction" -> {
                            val pending = pendingInstantOfferAction
                            pendingInstantOfferAction = null
                            result.success(pending)
                        }
                        "getPendingNotificationTap" -> {
                            val pending = pendingNotificationTap
                            pendingNotificationTap = null
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
        InstantOfferNotificationHelper.ensureChannel(this)
        captureInstantOfferIntent(intent)
        captureNotificationTap(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureInstantOfferIntent(intent)
        flushPendingInstantOfferAction()
        captureNotificationTap(intent)
        flushPendingNotificationTap()
    }

    /**
     * A tap on a rich notification we drew ourselves (booking requests) opens
     * this activity with the push data attached. FlutterFire never sees those
     * taps, so the payload is handed to Dart here to route like any other.
     */
    private fun captureNotificationTap(intent: Intent?) {
        if (intent == null) return
        // Instant-offer taps carry an action and are handled above.
        if (intent.hasExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ACTION)) return
        val payloadJson = intent.getStringExtra("notification_payload") ?: return
        val map = linkedMapOf<String, String>()
        try {
            val obj = JSONObject(payloadJson)
            val keys = obj.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = obj.optString(key)
            }
        } catch (_: Exception) {
            return
        }
        pendingNotificationTap = map
        intent.removeExtra("notification_payload")
    }

    private fun flushPendingNotificationTap() {
        val pending = pendingNotificationTap ?: return
        val channel = methodChannel ?: return
        pendingNotificationTap = null
        channel.invokeMethod("onNotificationTap", pending)
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
