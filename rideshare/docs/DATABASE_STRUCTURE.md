# 🗄️ هيكل قاعدة البيانات (Firestore)

## Collections Overview

```
Firestore/
├── users/
├── trips/
├── bookings/
├── payments/
├── ratings/
├── chats/
└── notifications/
```

---

## 📋 Collections Details

### 1. Users Collection

**Path:** `users/{userId}`

```javascript
{
  // Basic Info
  phoneNumber: string,           // "+201234567890"
  name: string,                  // "أحمد محمد"
  gender: "male" | "female",     // Required
  role: "passenger" | "driver" | "admin",
  
  // Localization & Country
  countryCode: string,           // "JO" | "SA" | "AE" | "QA" | "EG"
  currency: string,              // "JOD" | "SAR" | "AED" | "QAR" | "EGP"
  
  // Verification
  isPhoneVerified: boolean,      // SMS verification
  phoneVerifiedAt: timestamp,
  
  // Rating
  rating: number,                // Average (0-5)
  totalRatings: number,
  noShowCount: number,           // عدد المرات التي لم يحضر فيها الراكب بعد الحجز
  isBookingBlocked: boolean,     // هل تم حظره مؤقتاً من إنشاء حجوزات جديدة
  bookingBlockUntil: timestamp | null, // تاريخ انتهاء الحظر (إن وجد)
  
  // FCM
  fcmToken: string,              // For notifications
  
  // Metadata
  createdAt: timestamp,
  updatedAt: timestamp,
  lastLoginAt: timestamp
}
```

**Indexes:**
- `role` (ascending)
- `rating` (descending)
- `createdAt` (descending)

---

### 2. Trips Collection

**Path:** `trips/{tripId}`

```javascript
{
  // Driver Info
  driverId: string,
  driverName: string,
  driverPhone: string,
  
  // Location
  from: {
    name: string,                // "القاهرة"
    latitude: number,
    longitude: number,
    address: string
  },
  to: {
    name: string,                // "الإسكندرية"
    latitude: number,
    longitude: number,
    address: string
  },
  
  // Time
  departureTime: timestamp,
  
  // Pricing
  price: number,                 // Price per seat
  currency: string,              // "EGP" | "USD"
  
  // Seats
  totalSeats: number,
  availableSeats: number,
  
  // Seat Layout Configuration
  seatLayout: {
    rows: number,                 // 2, 3, 4, etc.
    seatsPerRow: number,          // 2, 3, 4, etc.
    preventGenderMixing: boolean   // true/false
  },
  
  // Seats Data
  seats: {
    seat1: {
      userId: string | null,
      userName: string | null,
      gender: "male" | "female" | null,
      bookedAt: timestamp | null
    },
    seat2: { ... },
    // ... dynamic based on totalSeats
  },
  
  // Car Image
  carImage: string,               // Storage URL
  
  // Status
  status: "active" | "hidden" | "deleted" | "completed",

  // Communication Fee Status (رسوم فتح التواصل مع الركاب)
  communicationFeeStatus: "not_required" | "pending" | "paid",
  
  // Metadata
  createdAt: timestamp,
  updatedAt: timestamp
}
```

**Indexes:**
- `status` + `departureTime` (composite)
- `driverId` + `status`
- `from.latitude` + `from.longitude` (geohash)
- `to.latitude` + `to.longitude` (geohash)

---

### 3. Bookings Collection

**Path:** `bookings/{bookingId}`

```javascript
{
  // Trip Reference
  tripId: string,
  
  // User Info (Passenger)
  userId: string,
  userName: string,
  userPhone: string,
  userGender: "male" | "female",
  sharePhoneWithDriver: boolean,  // هل يسمح الراكب بإظهار رقم هاتفه للسائق أم لا
  
  // Seat Info
  seatNumber: number,
  
  // Payment / Communication
  hasDriverPaidToContact: boolean, // true after أن يدفع السائق لفتح التواصل لهذه الحجز
  
  // Status
  status: "pending" | "confirmed" | "cancelled" | "no_show", // no_show = الراكب لم يحضر بعد التأكيد
  
  // Metadata
  createdAt: timestamp,
  cancelledAt: timestamp | null,
  cancelledBy: string | null      // "user" | "admin"
}
```

**Indexes:**
- `tripId` + `status`
- `userId` + `status`
- `createdAt` (descending)

---

### 4. Payments Collection

**Path:** `payments/{paymentId}`

```javascript
{
  // References
  tripId: string | null,          // For trip-related payments
  bookingId: string | null,       // For booking-related payments
  userId: string,                 // Owner of the payment (payer)
  driverId: string | null,        // Driver (usually same as userId for driver payments)
  
  // Purpose
  purpose: "driver_contact",     // دفعة واحدة من السائق لفتح التواصل لحجز/رحلة معيّنة
  
  // Amount
  amount: number,                 // Amount in local currency
  currency: string,
  
  // Payment Method
  method: "stripe" | "paymob" | "manual",
  
  // Status
  status: "pending" | "approved" | "rejected",
  
  // Manual Payment Details (if method = "manual")
  manualPayment: {
    walletType: "zain" | "cliq" | "orange" | null,
    walletNumber: string | null,
    qrCode: string | null,         // Storage URL
    proofImage: string | null,     // Storage URL
    notes: string | null
  },
  
  // Online Payment Details (if method = "stripe" | "paymob")
  onlinePayment: {
    transactionId: string | null,
    paymentIntentId: string | null,
    receiptUrl: string | null
  },
  
  // Approval (for manual payments)
  approvedAt: timestamp | null,
  approvedBy: string | null,       // adminId
  rejectedAt: timestamp | null,
  rejectedBy: string | null,
  rejectionReason: string | null,
  
  // Metadata
  createdAt: timestamp,
  updatedAt: timestamp
}
```

**Indexes:**
- `status` + `createdAt`
- `userId` + `status`
- `driverId` + `status`
- `method` + `status`

---

### 5. Ratings Collection

**Path:** `ratings/{ratingId}`

```javascript
{
  // Who rated whom
  fromUserId: string,              // Rater
  toUserId: string,                // Rated user
  tripId: string,
  
  // Rating Details
  rating: number,                  // 1-5
  comment: string | null,          // Optional
  
  // Context
  userRole: "passenger" | "driver", // Role of rater
  ratedRole: "passenger" | "driver", // Role of rated
  
  // Metadata
  createdAt: timestamp
}
```

**Indexes:**
- `toUserId` + `createdAt`
- `tripId` + `createdAt`
- `rating` (descending)

---

### 6. Chats Collection

**Path:** `chats/{chatId}`

```javascript
{
  // Trip Reference
  tripId: string,
  
  // Participants
  participants: [string],          // Array of userIds
  
  // Last Message Info
  lastMessage: string,
  lastMessageTime: timestamp,
  lastMessageSenderId: string,
  
  // Metadata
  createdAt: timestamp,
  updatedAt: timestamp,
  
  // Subcollection: messages
  messages/{messageId}: {
    senderId: string,
    senderName: string,
    text: string,
    timestamp: timestamp
  }
}
```

**Indexes:**
- `tripId` + `lastMessageTime`
- `participants` (array-contains)

---

### 7. Notifications Collection

**Path:** `notifications/{notificationId}`

```javascript
{
  // Target User
  userId: string,
  
  // Notification Type
  type: "booking" | "payment" | "trip_start" | 
        "driver_arrived" | "rating" | "chat" |
        "driver_contact_request" | "driver_contact_activated",
  
  // Content
  title: string,
  body: string,
  
  // Data Payload
  data: {
    tripId: string | null,
    bookingId: string | null,
    paymentId: string | null,
    chatId: string | null,
    // ... other relevant IDs
  },
  
  // Status
  read: boolean,
  readAt: timestamp | null,
  
  // Metadata
  createdAt: timestamp
}
```

**Indexes:**
- `userId` + `read` + `createdAt`
- `userId` + `type`

---

## 🔍 Query Examples

### Get Active Trips
```dart
FirebaseFirestore.instance
  .collection('trips')
  .where('status', isEqualTo: 'active')
  .where('departureTime', isGreaterThan: Timestamp.now())
  .orderBy('departureTime')
  .limit(20)
  .get();
```

### Get User Bookings
```dart
FirebaseFirestore.instance
  .collection('bookings')
  .where('userId', isEqualTo: userId)
  .where('status', isEqualTo: 'confirmed')
  .orderBy('createdAt', descending: true)
  .get();
```

### Get Pending Payments
```dart
FirebaseFirestore.instance
  .collection('payments')
  .where('status', isEqualTo: 'pending')
  .where('method', isEqualTo: 'manual')
  .orderBy('createdAt', descending: true)
  .get();
```

### Get Trip Chat
```dart
FirebaseFirestore.instance
  .collection('chats')
  .where('tripId', isEqualTo: tripId)
  .where('participants', arrayContains: userId)
  .get();
```

---

## 📊 Data Relationships

```
User (Driver)
  └── Creates → Trip
        ├── Has → Seats
        ├── Receives → Bookings (requests from passengers)
        └── Has → Chat (after دفع رسوم فتح التواصل)

User (Passenger)
  └── Creates → Booking (طلب انضمام)
        ├── References → Trip
        ├── Can Chat → بعد أن يدفع السائق رسوم فتح التواصل
        └── Can Rate → Driver

Trip
  └── Has → Multiple Bookings
  └── Has → One Chat
  └── Can Have → Multiple Ratings
```

---

## 🔐 Data Validation Rules

See [SECURITY_RULES.md](./SECURITY_RULES.md) for detailed validation rules.

---

**آخر تحديث:** 2024


