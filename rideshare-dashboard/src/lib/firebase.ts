import { initializeApp, type FirebaseApp } from "firebase/app"
import { getMessaging, getToken, isSupported, onMessage, type Messaging } from "firebase/messaging"
import { toast } from "sonner"

let app: FirebaseApp | null = null
let messaging: Messaging | null = null

const config = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
}

function hasFirebaseConfig() {
  return Object.values(config).every((value) => typeof value === "string" && value.length > 0)
}

async function getDashboardMessaging(): Promise<Messaging | null> {
  if (!hasFirebaseConfig()) return null
  if (!(await isSupported())) return null

  if (!app) {
    app = initializeApp(config)
  }
  if (!messaging) {
    messaging = getMessaging(app)
    onMessage(messaging, (payload) => {
      toast(payload.notification?.title || payload.data?.title || "VisionWay", {
        description: payload.notification?.body || payload.data?.body,
      })
    })
  }

  return messaging
}

async function registerMessagingWorker(): Promise<ServiceWorkerRegistration> {
  const search = new URLSearchParams({
    apiKey: config.apiKey,
    projectId: config.projectId,
    messagingSenderId: config.messagingSenderId,
    appId: config.appId,
  })

  return navigator.serviceWorker.register(`/firebase-messaging-sw.js?${search.toString()}`)
}

export async function requestDashboardWebPushToken(): Promise<string | null> {
  if (!("Notification" in window) || !("serviceWorker" in navigator)) {
    return null
  }

  const messagingInstance = await getDashboardMessaging()
  const vapidKey = import.meta.env.VITE_FIREBASE_VAPID_KEY
  if (!messagingInstance || !vapidKey) {
    return null
  }

  const permission =
    Notification.permission === "default"
      ? await Notification.requestPermission()
      : Notification.permission
  if (permission !== "granted") {
    return null
  }

  const serviceWorkerRegistration = await registerMessagingWorker()
  return getToken(messagingInstance, {
    vapidKey,
    serviceWorkerRegistration,
  })
}
