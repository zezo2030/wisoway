importScripts("https://www.gstatic.com/firebasejs/12.14.0/firebase-app-compat.js")
importScripts("https://www.gstatic.com/firebasejs/12.14.0/firebase-messaging-compat.js")

const params = new URL(self.location.href).searchParams
const firebaseConfig = {
  apiKey: params.get("apiKey") || "",
  projectId: params.get("projectId") || "",
  messagingSenderId: params.get("messagingSenderId") || "",
  appId: params.get("appId") || "",
}

if (firebaseConfig.apiKey && firebaseConfig.projectId && firebaseConfig.messagingSenderId && firebaseConfig.appId) {
  firebase.initializeApp(firebaseConfig)
  const messaging = firebase.messaging()

  messaging.onBackgroundMessage((payload) => {
    const title = payload.notification?.title || payload.data?.title || "VisionWay"
    const options = {
      body: payload.notification?.body || payload.data?.body || "",
      data: {
        link: payload.data?.link || "/notifications",
      },
    }

    self.registration.showNotification(title, options)
  })
}

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const link = event.notification.data?.link || "/notifications"
  const targetUrl = new URL(link, self.location.origin).href

  event.waitUntil(
    clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ("focus" in client) {
            client.navigate(targetUrl)
            return client.focus()
          }
        }
        return clients.openWindow(targetUrl)
      }),
  )
})
