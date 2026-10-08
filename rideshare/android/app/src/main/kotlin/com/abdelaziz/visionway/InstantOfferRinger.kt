package com.abdelaziz.visionway

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper

/**
 * Loops the new-ride chime while the in-app offer card is up (the tray
 * notification rings on its own through its channel). Always armed with a
 * deadline, so a card that never says "stop" can't leave the phone ringing.
 */
object InstantOfferRinger {
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var ringingOfferId: String? = null
    private val stopAtDeadline = Runnable { stop(null) }

    fun start(context: Context, offerId: String, untilMs: Long) {
        val remainingMs = untilMs - System.currentTimeMillis()
        if (remainingMs <= 0) return
        if (ringingOfferId == offerId && player != null) {
            rearm(remainingMs)
            return
        }
        stop(null)

        // Respect silent / vibrate the same way the notification channel does.
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        if (audio != null && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return

        val mp =
            MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                val afd =
                    context.resources.openRawResourceFd(R.raw.instant_offer_ring)
                        ?: return
                afd.use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
                isLooping = true
                setOnErrorListener { _, _, _ ->
                    stop(null)
                    true
                }
            }
        try {
            mp.prepare()
            mp.start()
        } catch (_: Exception) {
            mp.release()
            return
        }
        player = mp
        ringingOfferId = offerId
        rearm(remainingMs)
    }

    /** Stops the ring; with an [offerId], only if that offer is the one ringing. */
    fun stop(offerId: String?) {
        if (offerId != null && ringingOfferId != null && offerId != ringingOfferId) return
        handler.removeCallbacks(stopAtDeadline)
        player?.let {
            try {
                if (it.isPlaying) it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        player = null
        ringingOfferId = null
    }

    private fun rearm(remainingMs: Long) {
        handler.removeCallbacks(stopAtDeadline)
        handler.postDelayed(stopAtDeadline, remainingMs)
    }
}
