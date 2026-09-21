package com.abdelaziz.visionway

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles Accept/Reject taps on the rich instant-offer notification.
 * Cancels the notification and opens MainActivity with action extras for Flutter.
 */
class InstantOfferActionReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        val offerId =
            intent.getStringExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ID)
                ?: return
        val action =
            intent.getStringExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ACTION)
                ?: InstantOfferNotificationHelper.ACTION_OPEN
        val payload =
            intent.getStringExtra(InstantOfferNotificationHelper.EXTRA_PAYLOAD)

        InstantOfferNotificationHelper.cancel(context, offerId)

        val launch =
            Intent(context, MainActivity::class.java).apply {
                flags =
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ACTION, action)
                putExtra(InstantOfferNotificationHelper.EXTRA_OFFER_ID, offerId)
                if (payload != null) {
                    putExtra(InstantOfferNotificationHelper.EXTRA_PAYLOAD, payload)
                }
            }
        context.startActivity(launch)
    }
}
