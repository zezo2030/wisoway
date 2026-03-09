# ☁️ Cloud Functions - الدوال السحابية

## Overview

Cloud Functions تستخدم للمعالجة في الخلفية، الإشعارات، والعمليات التي تحتاج صلاحيات خاصة.

---

## Setup

### Initialize Functions

```bash
cd functions
npm install
```

### Dependencies

```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0"
  }
}
```

---

## Functions List

### 1. onBookingCreated
**Trigger:** عند إنشاء حجز جديد

**Purpose:** إرسال إشعار للسائق

```javascript
exports.onBookingCreated = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    const bookingId = context.params.bookingId;
    
    try {
      // Get trip data
      const tripDoc = await admin.firestore()
        .doc(`trips/${booking.tripId}`)
        .get();
      
      if (!tripDoc.exists) {
        console.error('Trip not found:', booking.tripId);
        return;
      }
      
      const trip = tripDoc.data();
      
      // Get driver data
      const driverDoc = await admin.firestore()
        .doc(`users/${trip.driverId}`)
        .get();
      
      if (!driverDoc.exists || !driverDoc.data().fcmToken) {
        console.error('Driver not found or no FCM token');
        return;
      }
      
      const driver = driverDoc.data();
      
      // Update trip available seats
      await admin.firestore()
        .doc(`trips/${booking.tripId}`)
        .update({
          availableSeats: admin.firestore.FieldValue.increment(-1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      
      // Send notification to driver
      await admin.messaging().send({
        token: driver.fcmToken,
        notification: {
          title: 'حجز جديد',
          body: `${booking.userName} حجز مقعد رقم ${booking.seatNumber}`,
        },
        data: {
          type: 'booking',
          tripId: booking.tripId,
          bookingId: bookingId,
          seatNumber: booking.seatNumber.toString()
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'bookings',
            sound: 'default'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      });
      
      // Create notification document
      await admin.firestore().collection('notifications').add({
        userId: trip.driverId,
        type: 'booking',
        title: 'حجز جديد',
        body: `${booking.userName} حجز مقعد رقم ${booking.seatNumber}`,
        data: {
          tripId: booking.tripId,
          bookingId: bookingId
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log('Notification sent to driver:', trip.driverId);
    } catch (error) {
      console.error('Error in onBookingCreated:', error);
    }
  });
```

---

### 2. onPaymentApproved
**Trigger:** عند الموافقة على دفع يدوي أو اكتمال عملية دفع إلكترونية

**Purpose:** تفعيل رسوم فتح التواصل (driver_contact) وإرسال إشعار مناسب

```javascript
exports.onPaymentApproved = functions.firestore
  .document('payments/{paymentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const paymentId = context.params.paymentId;
    
    // Only process if status changed from pending to approved
    if (before.status !== 'pending' || after.status !== 'approved') {
      return;
    }
    
    try {
      // Get user data (payer)
      const userDoc = await admin.firestore()
        .doc(`users/${after.userId}`)
        .get();
      
      if (!userDoc.exists || !userDoc.data().fcmToken) {
        console.error('User not found or no FCM token');
        return;
      }
      
      const user = userDoc.data();
      
      // تفعيل Communication Fee فقط عندما يكون الغرض driver_contact
      if (after.purpose === 'driver_contact' && after.bookingId) {
        await admin.firestore()
          .doc(`bookings/${after.bookingId}`)
          .update({
            hasDriverPaidToContact: true,
            status: 'confirmed',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
      }
      
      // Send notification to user
      await admin.messaging().send({
        token: user.fcmToken,
        notification: {
          title: 'تم تأكيد الدفع',
          body: 'تم معالجة دفعتك بنجاح',
        },
        data: {
          type: 'payment_approved',
          paymentId: paymentId,
          tripId: after.tripId || '',
          bookingId: after.bookingId || '',
          purpose: after.purpose || ''
        }
      });
      
      // Create notification document
      await admin.firestore().collection('notifications').add({
        userId: after.userId,
        type: 'payment',
        title: 'تم تأكيد الدفع',
        body: 'تم معالجة دفعتك بنجاح',
        data: {
          paymentId: paymentId,
          tripId: after.tripId || '',
          bookingId: after.bookingId || '',
          purpose: after.purpose || ''
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log('Payment approved notification sent');
    } catch (error) {
      console.error('Error in onPaymentApproved:', error);
    }
  });
```

---

### 3. sendTripReminder
**Trigger:** كل ساعة (Scheduled)

**Purpose:** إرسال تذكير قبل ساعة من موعد الرحلة

```javascript
exports.sendTripReminder = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('Africa/Cairo') // Adjust timezone
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const oneHourLater = new admin.firestore.Timestamp(
      now.seconds + 3600,
      now.nanoseconds
    );
    
    try {
      // Get trips starting in the next hour
      const tripsSnapshot = await admin.firestore()
        .collection('trips')
        .where('status', '==', 'active')
        .where('departureTime', '>=', now)
        .where('departureTime', '<=', oneHourLater)
        .get();
      
      if (tripsSnapshot.empty) {
        console.log('No trips starting in the next hour');
        return;
      }
      
      for (const tripDoc of tripsSnapshot.docs) {
        const trip = tripDoc.data();
        const tripId = tripDoc.id;
        
        // Get all confirmed bookings for this trip
        const bookingsSnapshot = await admin.firestore()
          .collection('bookings')
          .where('tripId', '==', tripId)
          .where('status', '==', 'confirmed')
          .get();
        
        if (bookingsSnapshot.empty) {
          continue;
        }
        
        // Send notification to each passenger
        for (const bookingDoc of bookingsSnapshot.docs) {
          const booking = bookingDoc.data();
          
          const userDoc = await admin.firestore()
            .doc(`users/${booking.userId}`)
            .get();
          
          if (!userDoc.exists || !userDoc.data().fcmToken) {
            continue;
          }
          
          const user = userDoc.data();
          
          // Check if notification already sent (prevent duplicates)
          const existingNotification = await admin.firestore()
            .collection('notifications')
            .where('userId', '==', booking.userId)
            .where('type', '==', 'trip_start')
            .where('data.tripId', '==', tripId)
            .limit(1)
            .get();
          
          if (!existingNotification.empty) {
            continue; // Already notified
          }
          
          await admin.messaging().send({
            token: user.fcmToken,
            notification: {
              title: 'تذكير بالرحلة',
              body: `رحلتك من ${trip.from.name} ستبدأ خلال ساعة`,
            },
            data: {
              type: 'trip_start',
              tripId: tripId
            }
          });
          
          // Create notification document
          await admin.firestore().collection('notifications').add({
            userId: booking.userId,
            type: 'trip_start',
            title: 'تذكير بالرحلة',
            body: `رحلتك من ${trip.from.name} ستبدأ خلال ساعة`,
            data: {
              tripId: tripId
            },
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }
      
      console.log(`Processed ${tripsSnapshot.size} trips`);
    } catch (error) {
      console.error('Error in sendTripReminder:', error);
    }
  });
```

---

### 4. onRatingCreated
**Trigger:** عند إنشاء تقييم جديد

**Purpose:** تحديث متوسط تقييم المستخدم

```javascript
exports.onRatingCreated = functions.firestore
  .document('ratings/{ratingId}')
  .onCreate(async (snap, context) => {
    const rating = snap.data();
    
    try {
      const userRef = admin.firestore().doc(`users/${rating.toUserId}`);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        console.error('User not found:', rating.toUserId);
        return;
      }
      
      const user = userDoc.data();
      const currentRating = user.rating || 0;
      const totalRatings = user.totalRatings || 0;
      
      // Calculate new average rating
      const newRating = (currentRating * totalRatings + rating.rating) / (totalRatings + 1);
      
      await userRef.update({
        rating: newRating,
        totalRatings: totalRatings + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Updated rating for user ${rating.toUserId}: ${newRating}`);
    } catch (error) {
      console.error('Error in onRatingCreated:', error);
    }
  });
```

---

### 5. onDriverArrived
**Trigger:** HTTP Call (Callable Function)

**Purpose:** إرسال إشعار عند وصول السائق

```javascript
exports.onDriverArrived = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const { tripId } = data;
  
  if (!tripId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'tripId is required'
    );
  }
  
  try {
    // Get trip data
    const tripDoc = await admin.firestore()
      .doc(`trips/${tripId}`)
      .get();
    
    if (!tripDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Trip not found'
      );
    }
    
    const trip = tripDoc.data();
    
    // Verify caller is the driver
    if (trip.driverId !== context.auth.uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only driver can mark arrival'
      );
    }
    
    // Get all confirmed bookings
    const bookingsSnapshot = await admin.firestore()
      .collection('bookings')
      .where('tripId', '==', tripId)
      .where('status', '==', 'confirmed')
      .get();
    
    if (bookingsSnapshot.empty) {
      return { success: true, message: 'No passengers to notify' };
    }
    
    // Send notification to each passenger
    const notifications = [];
    
    for (const bookingDoc of bookingsSnapshot.docs) {
      const booking = bookingDoc.data();
      
      const userDoc = await admin.firestore()
        .doc(`users/${booking.userId}`)
        .get();
      
      if (!userDoc.exists || !userDoc.data().fcmToken) {
        continue;
      }
      
      const user = userDoc.data();
      
      // Send FCM notification
      await admin.messaging().send({
        token: user.fcmToken,
        notification: {
          title: 'وصل السائق',
          body: `السائق وصل إلى نقطة الانطلاق: ${trip.from.name}`,
        },
        data: {
          type: 'driver_arrived',
          tripId: tripId
        }
      });
      
      // Create notification document
      notifications.push(
        admin.firestore().collection('notifications').add({
          userId: booking.userId,
          type: 'driver_arrived',
          title: 'وصل السائق',
          body: `السائق وصل إلى نقطة الانطلاق: ${trip.from.name}`,
          data: {
            tripId: tripId
          },
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        })
      );
    }
    
    await Promise.all(notifications);
    
    return { 
      success: true, 
      message: `Notifications sent to ${bookingsSnapshot.size} passengers` 
    };
  } catch (error) {
    console.error('Error in onDriverArrived:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send notifications',
      error.message
    );
  }
});
```

---

### 6. onTripCompleted
**Trigger:** Manual (via HTTP or scheduled)

**Purpose:** تحديث حالة الرحلة بعد انتهائها

```javascript
exports.onTripCompleted = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }
  
  const { tripId } = data;
  
  try {
    const tripDoc = await admin.firestore().doc(`trips/${tripId}`).get();
    
    if (!tripDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Trip not found');
    }
    
    const trip = tripDoc.data();
    
    // Only driver or admin can complete trip
    if (trip.driverId !== context.auth.uid && 
        !(await isAdmin(context.auth.uid))) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    }
    
    await admin.firestore().doc(`trips/${tripId}`).update({
      status: 'completed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Notify passengers that trip is completed and they can rate
    const bookingsSnapshot = await admin.firestore()
      .collection('bookings')
      .where('tripId', '==', tripId)
      .where('status', '==', 'confirmed')
      .get();
    
    for (const bookingDoc of bookingsSnapshot.docs) {
      const booking = bookingDoc.data();
      const userDoc = await admin.firestore().doc(`users/${booking.userId}`).get();
      
      if (userDoc.exists && userDoc.data().fcmToken) {
        await admin.messaging().send({
          token: userDoc.data().fcmToken,
          notification: {
            title: 'انتهت الرحلة',
            body: 'يمكنك الآن تقييم الرحلة والسائق',
          },
          data: {
            type: 'trip_completed',
            tripId: tripId
          }
        });
      }
    }
    
    return { success: true };
  } catch (error) {
    console.error('Error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

async function isAdmin(userId) {
  const userDoc = await admin.firestore().doc(`users/${userId}`).get();
  return userDoc.exists && userDoc.data().role === 'admin';
}
```

---

### 7. reportNoShow (Passenger No-show)
**Trigger:** Callable Function (HTTP - `functions.https.onCall`)

**Purpose:** يسمح للسائق بالإبلاغ عن راكب لم يحضر إلى نقطة اللقاء بعد حجز مؤكد.

```javascript
exports.reportNoShow = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const { bookingId } = data;

  if (!bookingId) {
    throw new functions.https.HttpsError('invalid-argument', 'bookingId is required');
  }

  try {
    // Get booking data
    const bookingRef = admin.firestore().doc(`bookings/${bookingId}`);
    const bookingDoc = await bookingRef.get();

    if (!bookingDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Booking not found');
    }

    const booking = bookingDoc.data();

    // Get trip to verify caller is the driver
    const tripDoc = await admin.firestore().doc(`trips/${booking.tripId}`).get();
    if (!tripDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Trip not found');
    }

    const trip = tripDoc.data();

    if (trip.driverId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only driver can report no-show');
    }

    // Mark booking as no_show (if it was confirmed)
    if (booking.status === 'confirmed') {
      await bookingRef.update({
        status: 'no_show',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Increment passenger noShowCount
      const userRef = admin.firestore().doc(`users/${booking.userId}`);
      await userRef.update({
        noShowCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    return { success: true };
  } catch (error) {
    console.error('Error in reportNoShow:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

## Deployment

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:onBookingCreated

# View logs
firebase functions:log
```

---

## Testing

استخدم Firebase Emulator:

```bash
firebase emulators:start --only functions
```

---

**آخر تحديث:** 2024


