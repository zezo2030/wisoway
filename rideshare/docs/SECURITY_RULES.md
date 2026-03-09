# 🔐 Firestore Security Rules

## Rules Overview

هذه القواعد تحمي قاعدة البيانات وتضمن أن المستخدمين يمكنهم فقط الوصول إلى البيانات المسموح لهم بها.

---

## Complete Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // Helper Functions
    // ============================================
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    function isDriver() {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'driver';
    }
    
    function isPhoneVerified() {
      return isAuthenticated() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isPhoneVerified == true;
    }
    
    // Check if user can book a seat (gender mixing prevention)
    function canBookSeat(tripId, seatNumber, userGender) {
      let trip = get(/databases/$(database)/documents/trips/$(tripId));
      let seats = trip.data.seats;
      let seatKey = 'seat' + string(seatNumber);
      let layout = trip.data.seatLayout;
      
      // Check if seat exists and is empty
      if (!(seatKey in seats) || seats[seatKey].userId != null) {
        return false;
      }
      
      // Check gender mixing if enabled
      if (layout.preventGenderMixing == true) {
        let prevSeatKey = 'seat' + string(seatNumber - 1);
        let nextSeatKey = 'seat' + string(seatNumber + 1);
        
        // Check left seat
        if (prevSeatKey in seats && seats[prevSeatKey].userId != null) {
          if (userGender == 'male' && seats[prevSeatKey].gender == 'female') {
            return false;
          }
          if (userGender == 'female' && seats[prevSeatKey].gender == 'male') {
            return false;
          }
        }
        
        // Check right seat
        if (nextSeatKey in seats && seats[nextSeatKey].userId != null) {
          if (userGender == 'male' && seats[nextSeatKey].gender == 'female') {
            return false;
          }
          if (userGender == 'female' && seats[nextSeatKey].gender == 'male') {
            return false;
          }
        }
      }
      
      return true;
    }
    
    // ============================================
    // Users Collection
    // ============================================
    
    match /users/{userId} {
      // Anyone authenticated can read user profiles
      allow read: if isAuthenticated();
      
      // Users can create their own profile
      // Flexible: Allow creation via Email (no phone yet) or via Phone Auth
      allow create: if isAuthenticated() && isOwner(userId) && (
        // Case 1: Traditional Phone Auth match
        (!("phoneNumber" in request.resource.data) || request.resource.data.phoneNumber == request.auth.token.phone_number) ||
        // Case 2: Custom OTP via Cloud Functions (we verify this later via update)
        (request.resource.data.provider == 'email')
      );
      
      // Users can update their own profile
      allow update: if isOwner(userId) && (
        // Can't change role unless admin
        request.resource.data.role == resource.data.role || isAdmin()
      );
      
      // Only admin can change user roles independently
      allow update: if isAdmin();
      
      // Only admin can delete users
      allow delete: if isAdmin();
    }
    
    // ============================================
    // Trips Collection
    // ============================================
    
    match /trips/{tripId} {
      // Anyone authenticated can read active trips
      allow read: if isAuthenticated();
      
      // Only verified drivers can create trips
      allow create: if isAuthenticated() && 
        isDriver() && 
        isPhoneVerified() &&
        request.resource.data.driverId == request.auth.uid;
      
      // Driver can update their own trips, Admin can update any
      allow update: if isAuthenticated() && (
        resource.data.driverId == request.auth.uid || isAdmin()
      );
      
      // Only admin can delete trips
      allow delete: if isAdmin();
      
      // Special rule for seat booking
      // This validates seat booking with gender mixing prevention
      allow update: if isAuthenticated() && 
        isPhoneVerified() &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['seats']) &&
        // Validate each seat change
        validateSeatBooking(tripId, request.resource.data.seats, resource.data.seats);
    }
    
    // Helper function to validate seat booking
    function validateSeatBooking(tripId, newSeats, oldSeats) {
      let user = get(/databases/$(database)/documents/users/$(request.auth.uid));
      let userGender = user.data.gender;
      
      // Check each changed seat
      return newSeats.keys().hasAll(oldSeats.keys()) &&
        newSeats.keys().filter(key => 
          newSeats[key].userId != oldSeats[key].userId
        ).map(key => {
          let seatNumber = int(val(key.replace('seat', '')));
          return canBookSeat(tripId, seatNumber, userGender);
        }).toSet().hasOnly([true]);
    }
    
    // ============================================
    // Bookings Collection
    // ============================================
    
    match /bookings/{bookingId} {
      // Users can read their own bookings
      // Drivers can read bookings for their trips
      // Admins can read all
      allow read: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        isAdmin() ||
        // Driver can read if it's their trip
        (isDriver() && 
         get(/databases/$(database)/documents/trips/$(resource.data.tripId)).data.driverId == request.auth.uid)
      );
      
      // Authenticated users can create bookings
      allow create: if isAuthenticated() && 
        isPhoneVerified() &&
        request.resource.data.userId == request.auth.uid;
      
      // No one can update bookings (no cancellation allowed)
      allow update: if false;
      
      // Only admin can delete bookings
      allow delete: if isAdmin();
    }
    
    // ============================================
    // Payments Collection
    // ============================================
    
    match /payments/{paymentId} {
      // Users can read their own payments
      // Drivers can read payments for their trips
      // Admins can read all
      allow read: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        (isDriver() && 
         get(/databases/$(database)/documents/trips/$(resource.data.tripId)).data.driverId == request.auth.uid) ||
        isAdmin()
      );
      
      // Users can create payments for their bookings
      allow create: if isAuthenticated() && 
        isPhoneVerified() &&
        request.resource.data.userId == request.auth.uid;
      
      // Only admin can approve/reject manual payments
      allow update: if isAdmin() && 
        request.resource.data.diff(resource.data).affectedKeys().hasAny(['status', 'approvedAt', 'approvedBy', 'rejectedAt', 'rejectedBy']);
      
      // No one else can update
      allow update: if false;
      
      // Only admin can delete
      allow delete: if isAdmin();
    }
    
    // ============================================
    // Ratings Collection
    // ============================================
    
    match /ratings/{ratingId} {
      // Anyone authenticated can read ratings
      allow read: if isAuthenticated();
      
      // Users can create ratings for trips they participated in
      allow create: if isAuthenticated() && 
        isPhoneVerified() &&
        request.resource.data.fromUserId == request.auth.uid &&
        // Verify user was part of the trip
        validateUserInTrip(request.resource.data.tripId, request.auth.uid);
      
      // Only admin can update ratings
      allow update: if isAdmin();
      
      // Only admin can delete ratings
      allow delete: if isAdmin();
    }
    
    // Helper to validate user was in trip
    function validateUserInTrip(tripId, userId) {
      let trip = get(/databases/$(database)/documents/trips/$(tripId));
      let seats = trip.data.seats;
      
      // Check if user has a booking
      return exists(/databases/$(database)/documents/bookings/$(tripId + '_' + userId)) ||
        // Or check seats
        seats.keys().map(key => seats[key].userId).hasAny([userId]);
    }
    
    // ============================================
    // Chats Collection
    // ============================================
    
    match /chats/{chatId} {
      // Only participants can read
      allow read: if isAuthenticated() && 
        request.auth.uid in resource.data.participants;
      
      // Anyone authenticated can create chat for a trip
      allow create: if isAuthenticated() && 
        isPhoneVerified() &&
        request.auth.uid in request.resource.data.participants;
      
      // Participants can update (last message, etc.)
      allow update: if isAuthenticated() && 
        request.auth.uid in resource.data.participants;
      
      // Messages subcollection
      match /messages/{messageId} {
        // Participants can read messages
        allow read: if isAuthenticated() && 
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        
        // Users can send messages
        allow create: if isAuthenticated() && 
          isPhoneVerified() &&
          request.resource.data.senderId == request.auth.uid &&
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        
        // No updates or deletes
        allow update, delete: if false;
      }
    }
    
    // ============================================
    // Notifications Collection
    // ============================================
    
    match /notifications/{notificationId} {
      // Users can only read their own notifications
      allow read: if isAuthenticated() && 
        resource.data.userId == request.auth.uid;
      
      // System can create notifications (via Cloud Functions)
      allow create: if isAuthenticated();
      
      // Users can update their own notifications (mark as read)
      allow update: if isAuthenticated() && 
        resource.data.userId == request.auth.uid &&
        request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read', 'readAt']);
      
      // Users can delete their own notifications
      allow delete: if isAuthenticated() && 
        resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 🔒 Security Best Practices

### 1. Phone Verification
- جميع العمليات المهمة تتطلب `isPhoneVerified()`
- لا يمكن حجز مقعد بدون التحقق من الهاتف

### 2. Role-based Access
- الأدمن فقط يمكنه الموافقة على المدفوعات
- السائق فقط يمكنه إنشاء رحلات
- لا يمكن للمستخدم تغيير دوره

### 3. Data Validation
- التحقق من صحة البيانات قبل الحفظ
- منع التلاعب بالبيانات الحساسة

### 4. Seat Booking Protection
- منع الحجز المزدوج
- تطبيق قواعد منع الاختلاط

---

## 🧪 Testing Security Rules

استخدم Firebase Emulator Suite لاختبار القواعد:

```bash
firebase emulators:start --only firestore
```

---

## 📝 Notes

- القواعد تعمل على مستوى Collection و Document
- استخدم Helper Functions لتقليل التكرار
- اختبر القواعد جيداً قبل النشر

---

**آخر تحديث:** 2024







