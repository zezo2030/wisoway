# 📅 الأسبوع الرابع: Communication Fee & Payment Flow

## 🎯 الأهداف

1. Communication Fee Flow (رسوم فتح التواصل لكل رحلة/حجز)
2. Stripe/Paymob Integration (دفع مباشر من السائق)
3. Manual Payment (Wallet, QR, Proof) كطرق دفع خارجية فقط
4. Payment Status Management & Notifications
5. Cloud Functions for Payment

---

## ✅ Checklist

### Day 1-2: Communication Fee UI
- [ ] Communication fee dialog when driver taps "فتح التواصل"
- [ ] Show fixed fee based on country/currency
- [ ] Confirm & Pay button
- [ ] Payment method selection (Stripe / Paymob / Manual)
- [ ] Display fee amount in local currency

### Day 3-4: Online Payment (Direct)
- [ ] Stripe integration (direct charge per communication)
- [ ] Paymob integration (direct charge per communication)
- [ ] Payment processing
- [ ] Success/Error handling
- [ ] Payment webhook handling (Cloud Functions)

### Day 5: Manual Payment
- [ ] Wallet number input (Zain Cash / Orange Money / Vodafone Cash / Cliq ...etc)
- [ ] QR Code display
- [ ] Proof image upload (image picker + Firebase Storage)
- [ ] Payment submission
- [ ] Manual payment form validation

### Day 6-7: Payment Management
- [ ] Create payment document (purpose = driver_contact)
- [ ] Cloud Functions to confirm driver_contact payments
- [ ] Notifications when communication activated
- [ ] Update booking status after payment approval
- [ ] Payment history screen

---

## 📋 تفاصيل التنفيذ

### 1. Communication Fee Structure

#### الرسوم الثابتة حسب البلد:
```dart
// lib/core/constants/communication_fees.dart
const Map<String, double> COMMUNICATION_FEES = {
  'JO': 2.0,   // JOD
  'SA': 10.0,  // SAR
  'AE': 25.0,  // AED
  'QA': 25.0,  // QAR
  'EG': 50.0,  // EGP
};
```

#### متى يتم طلب الرسوم:
- عندما يضغط السائق على زر "فتح التواصل" في:
  - شاشة تفاصيل الحجز (Booking Details)
  - قائمة الحجوزات (Bookings List)
- يتم التحقق من `hasDriverPaidToContact` في Booking
- إذا كان `false`، يتم عرض Dialog للدفع

---

### 2. Payment Model

```dart
// lib/models/payment_model.dart
class Payment {
  final String id;
  final String tripId;
  final String? bookingId;
  final String userId;        // السائق (الذي يدفع)
  final String? driverId;
  final String purpose;       // "driver_contact"
  final double amount;
  final String currency;
  final PaymentMethod method; // stripe, paymob, manual
  final PaymentStatus status; // pending, approved, rejected
  final ManualPayment? manualPayment;
  final OnlinePayment? onlinePayment;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum PaymentMethod { stripe, paymob, manual }
enum PaymentStatus { pending, approved, rejected }

class ManualPayment {
  final String? walletType;  // zain, cliq, orange, vodafone
  final String? walletNumber;
  final String? qrCode;      // Storage URL
  final String? proofImage;   // Storage URL
  final String? notes;
}

class OnlinePayment {
  final String? transactionId;
  final String? paymentIntentId;
  final String? receiptUrl;
}
```

---

### 3. Communication Fee Dialog

#### المكونات المطلوبة:
1. **Dialog Header**: عنوان "رسوم فتح التواصل"
2. **Fee Display**: عرض المبلغ بالعملة المحلية
3. **Payment Method Selection**: 
   - Stripe (بطاقة ائتمان)
   - Paymob (بطاقة ائتمان)
   - Manual (محفظة إلكترونية)
4. **Action Buttons**: 
   - إلغاء
   - تأكيد ودفع

#### التدفق:
```
Driver taps "فتح التواصل"
  ↓
Check hasDriverPaidToContact
  ↓
If false → Show Communication Fee Dialog
  ↓
User selects payment method
  ↓
If Online → Process payment → Create payment doc (status: approved)
  ↓
If Manual → Show form → Submit → Create payment doc (status: pending)
  ↓
Cloud Function approves → Update booking.hasDriverPaidToContact = true
```

---

### 4. Payment Service

#### الوظائف المطلوبة:

```dart
// lib/core/services/payment_service.dart
class PaymentService {
  // إنشاء دفع جديد
  Future<Payment> createPayment({
    required String tripId,
    required String? bookingId,
    required double amount,
    required String currency,
    required PaymentMethod method,
    ManualPayment? manualPayment,
  });
  
  // معالجة دفع Stripe
  Future<PaymentResult> processStripePayment({
    required String paymentId,
    required String cardToken,
  });
  
  // معالجة دفع Paymob
  Future<PaymentResult> processPaymobPayment({
    required String paymentId,
    required Map<String, dynamic> paymentData,
  });
  
  // رفع صورة إثبات الدفع
  Future<String> uploadProofImage(File imageFile);
  
  // الحصول على حالة الدفع
  Stream<Payment> getPaymentStream(String paymentId);
  
  // الحصول على تاريخ المدفوعات
  Future<List<Payment>> getPaymentHistory(String userId);
}
```

---

### 5. Stripe Integration

#### المتطلبات:
1. **Dependencies**:
   ```yaml
   dependencies:
     stripe_payment: ^1.1.4
   ```

2. **Setup**:
   - Stripe Account
   - Publishable Key (في app)
   - Secret Key (في Cloud Functions)

3. **Flow**:
   ```
   User selects Stripe
     ↓
   Show card input form
     ↓
   Create payment intent (Cloud Function)
     ↓
   Confirm payment (Stripe SDK)
     ↓
   Webhook → Update payment status
   ```

#### Cloud Function:
```javascript
// functions/payment_functions.js
exports.createStripePaymentIntent = functions.https.onCall(async (data, context) => {
  const { amount, currency, paymentId } = data;
  
  const paymentIntent = await stripe.paymentIntents.create({
    amount: Math.round(amount * 100), // Convert to cents
    currency: currency.toLowerCase(),
    metadata: { paymentId }
  });
  
  return { clientSecret: paymentIntent.client_secret };
});
```

---

### 6. Paymob Integration

#### المتطلبات:
1. **Dependencies**:
   ```yaml
   dependencies:
     http: ^1.1.0
   ```

2. **Setup**:
   - Paymob Account
   - API Key
   - Integration ID

3. **Flow**:
   ```
   User selects Paymob
     ↓
   Create payment key (Cloud Function)
     ↓
   Redirect to Paymob payment page
     ↓
   Callback → Update payment status
   ```

#### Cloud Function:
```javascript
exports.createPaymobPaymentKey = functions.https.onCall(async (data, context) => {
  const { amount, currency, paymentId } = data;
  
  // Create order
  const orderResponse = await axios.post('https://accept.paymob.com/api/ecommerce/orders', {
    auth_token: PAYMOB_AUTH_TOKEN,
    delivery_needed: false,
    amount_cents: Math.round(amount * 100),
    currency: currency,
    items: []
  });
  
  // Create payment key
  const paymentKeyResponse = await axios.post('https://accept.paymob.com/api/acceptance/payment_keys', {
    auth_token: PAYMOB_AUTH_TOKEN,
    amount_cents: Math.round(amount * 100),
    expiration: 3600,
    order_id: orderResponse.data.id,
    billing_data: {
      // User billing data
    },
    currency: currency,
    integration_id: PAYMOB_INTEGRATION_ID
  });
  
  return { paymentKey: paymentKeyResponse.data.token };
});
```

---

### 7. Manual Payment Form

#### المكونات:
1. **Wallet Type Selection**: Dropdown
   - Zain Cash (الأردن)
   - Orange Money (الأردن)
   - Cliq (الأردن)
   - Vodafone Cash (مصر)
   - etc.

2. **Wallet Number Input**: TextField
   - Validation: رقم صحيح

3. **QR Code Display**: 
   - عرض QR Code للدفع (إن وجد)
   - أو رقم المحفظة

4. **Proof Image Upload**:
   - Image Picker
   - Upload to Firebase Storage
   - Display preview

5. **Notes Field**: Optional

#### Validation:
- Wallet type: required
- Wallet number: required, valid format
- Proof image: required

---

### 8. Cloud Functions

#### onPaymentApproved
```javascript
// functions/payment_functions.js
exports.onPaymentApproved = functions.firestore
  .document('payments/{paymentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Only process if status changed from pending to approved
    if (before.status !== 'pending' || after.status !== 'approved') {
      return;
    }
    
    // If purpose is driver_contact, update booking
    if (after.purpose === 'driver_contact' && after.bookingId) {
      await admin.firestore()
        .doc(`bookings/${after.bookingId}`)
        .update({
          hasDriverPaidToContact: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      
      // Send notification to driver
      // Send notification to passenger
    }
  });
```

#### Stripe Webhook
```javascript
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const event = stripe.webhooks.constructEvent(req.body, sig, STRIPE_WEBHOOK_SECRET);
  
  if (event.type === 'payment_intent.succeeded') {
    const paymentIntent = event.data.object;
    const paymentId = paymentIntent.metadata.paymentId;
    
    await admin.firestore()
      .doc(`payments/${paymentId}`)
      .update({
        status: 'approved',
        'onlinePayment.transactionId': paymentIntent.id,
        'onlinePayment.paymentIntentId': paymentIntent.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
  }
  
  res.json({ received: true });
});
```

---

### 9. Payment History Screen

#### المكونات:
- List of payments
- Filter by status (pending, approved, rejected)
- Payment details:
  - Amount & Currency
  - Method
  - Status
  - Date
  - Purpose (driver_contact)
  - Related trip/booking

---

## 📝 Key Files

### Models
- `lib/models/payment_model.dart` - Payment data model
- `lib/models/manual_payment_model.dart` - Manual payment details

### Services
- `lib/core/services/payment_service.dart` - Payment operations
- `lib/core/services/stripe_service.dart` - Stripe integration
- `lib/core/services/paymob_service.dart` - Paymob integration

### Screens
- `lib/screens/driver/communication_fee_dialog.dart` - Fee dialog
- `lib/screens/payment/payment_method_selection_screen.dart` - Payment method selection
- `lib/screens/payment/manual_payment_screen.dart` - Manual payment form
- `lib/screens/payment/payment_history_screen.dart` - Payment history

### Widgets
- `lib/widgets/payment_method_widget.dart` - Payment method card
- `lib/widgets/proof_image_upload_widget.dart` - Image upload widget
- `lib/widgets/qr_code_display_widget.dart` - QR code display

### Constants
- `lib/core/constants/communication_fees.dart` - Fee amounts by country
- `lib/core/constants/payment_constants.dart` - Payment constants

### Cloud Functions
- `functions/payment_functions.js` - Payment-related functions
  - `createStripePaymentIntent`
  - `createPaymobPaymentKey`
  - `onPaymentApproved`
  - `stripeWebhook`
  - `paymobWebhook`

---

## 🔐 Security Considerations

1. **API Keys**: 
   - Store Stripe/Paymob secret keys in Cloud Functions only
   - Use environment variables for sensitive data

2. **Payment Validation**:
   - Always verify payment on server side
   - Use webhooks for payment confirmation
   - Never trust client-side payment status

3. **Manual Payment Approval**:
   - Only admins can approve manual payments
   - Require proof image for manual payments
   - Validate payment amount matches fee

4. **Firestore Rules**:
   ```javascript
   match /payments/{paymentId} {
     allow read: if request.auth != null && 
                    (resource.data.userId == request.auth.uid ||
                     resource.data.driverId == request.auth.uid);
     allow create: if request.auth != null && 
                     request.resource.data.userId == request.auth.uid;
     allow update: if request.auth != null && 
                     (resource.data.userId == request.auth.uid ||
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
   }
   ```

---

## 🧪 Testing Checklist

- [ ] Communication fee dialog appears when driver taps "فتح التواصل"
- [ ] Fee amount is correct based on country
- [ ] Stripe payment flow works end-to-end
- [ ] Paymob payment flow works end-to-end
- [ ] Manual payment form validation works
- [ ] Proof image uploads correctly
- [ ] Payment document is created correctly
- [ ] Cloud Function updates booking after approval
- [ ] Notifications are sent after payment approval
- [ ] Payment history displays correctly

---

**Next:** [WEEK_05.md](./WEEK_05.md)


