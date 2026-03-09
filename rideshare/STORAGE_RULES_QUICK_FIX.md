# 🔧 إصلاح سريع: Firebase Storage Rules

## المشكلة

```
❌ Error uploading image: [firebase_storage/unauthorized] 
User is not authorized to perform the desired action.
```

**السبب:** القواعد في Firebase Console تمنع جميع العمليات.

---

## الحل السريع (للتطوير)

### الخطوة 1: افتح Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: `rideshare-5f785`
3. من القائمة الجانبية، اختر **Storage**
4. اضغط على **Rules**

### الخطوة 2: انسخ القواعد التالية

**للتطوير (مفتوحة للمستخدمين المسجلين):**

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to read/write/delete
    match /{allPaths=**} {
      allow read, write, delete: if request.auth != null;
    }
  }
}
```

**أو للإنتاج (آمنة ومقيدة):**

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the file
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // ============================================
    // Profile Pictures
    // ============================================
    match /profiles/{userId}/{fileName} {
      // Users can upload their own profile picture
      allow write: if isOwner(userId) && 
                     request.resource.size < 5 * 1024 * 1024 && // 5MB max
                     request.resource.contentType.matches('image/.*');
      
      // Anyone authenticated can read profile pictures
      allow read: if isAuthenticated();
      
      // Users can delete their own profile picture
      allow delete: if isOwner(userId);
    }
    
    // ============================================
    // Driver Licenses
    // ============================================
    match /driver_licenses/{userId}/{fileName} {
      // Users can upload their own driver license
      allow write: if isOwner(userId) && 
                     request.resource.size < 5 * 1024 * 1024 && // 5MB max
                     request.resource.contentType.matches('image/.*');
      
      // Only the owner can read driver licenses
      allow read: if isOwner(userId);
      
      // Users can delete their own driver license
      allow delete: if isOwner(userId);
    }
    
    // ============================================
    // Vehicle Licenses
    // ============================================
    match /vehicle_licenses/{userId}/{fileName} {
      // Users can upload their own vehicle license
      allow write: if isOwner(userId) && 
                     request.resource.size < 5 * 1024 * 1024 && // 5MB max
                     request.resource.contentType.matches('image/.*');
      
      // Only the owner can read vehicle licenses
      allow read: if isOwner(userId);
      
      // Users can delete their own vehicle license
      allow delete: if isOwner(userId);
    }
    
    // ============================================
    // Trip Images (for future use)
    // ============================================
    match /trips/{tripId}/{fileName} {
      // Trip creators can upload images
      allow write: if isAuthenticated() && 
                     request.resource.size < 10 * 1024 * 1024 && // 10MB max
                     request.resource.contentType.matches('image/.*');
      
      // Anyone authenticated can read trip images
      allow read: if isAuthenticated();
      
      // Trip creators can delete images
      allow delete: if isAuthenticated();
    }
    
    // ============================================
    // Default: Deny all other paths
    // ============================================
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### الخطوة 3: الصق في Firebase Console

1. احذف القواعد القديمة
2. الصق القواعد الجديدة
3. اضغط **Publish**

---

## التحقق من الإعداد

بعد نشر القواعد:

1. تأكد من أن المستخدم **مسجل دخول** في Firebase Auth (ليس Firestore-only mode)
2. جرب رفع صورة من التطبيق
3. يجب أن تعمل بدون أخطاء

---

## ملاحظات مهمة

### ⚠️ للتطوير:
- استخدم القواعد المفتوحة (`allow read, write, delete: if request.auth != null`)
- هذه القواعد تسمح لجميع المستخدمين المسجلين بالرفع

### ✅ للإنتاج:
- استخدم القواعد الآمنة (من `storage.rules`)
- هذه القواعد تسمح للمستخدمين برفع ملفاتهم فقط

---

## استخدام Firebase CLI (اختياري)

إذا كان لديك Firebase CLI مثبت:

```bash
# نشر قواعد Storage
firebase deploy --only storage
```

---

## الملفات في المشروع

- `storage.rules` - قواعد للإنتاج (آمنة)
- `storage.rules.dev` - قواعد للتطوير (مفتوحة)

---

## روابط مفيدة

- [Firebase Storage Rules Documentation](https://firebase.google.com/docs/storage/security)
- [STORAGE_SETUP.md](./STORAGE_SETUP.md) - دليل إعداد Storage الكامل

