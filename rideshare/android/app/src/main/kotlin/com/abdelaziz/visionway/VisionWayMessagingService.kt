package com.abdelaziz.visionway

import android.app.ActivityManager
import android.content.Context
import android.os.Process
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Intercepts booking_created FCM data messages to show the rich shared-trip
 * notification while delegating everything else to FlutterFire.
 */
class VisionWayMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        if (data["type"] == "booking_created" && !isAppInForeground()) {
            BookingNotificationHelper.show(applicationContext, data)
        }
        super.onMessageReceived(message)
    }

    private fun isAppInForeground(): Boolean {
        val activityManager =
            getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return false
        val appProcesses = activityManager.runningAppProcesses ?: return false
        val packageName = applicationContext.packageName
        val myPid = Process.myPid()
        return appProcesses.any {
            it.pid == myPid &&
                it.processName == packageName &&
                it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        }
    }
}
