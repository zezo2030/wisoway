# 🔧 حل مشكلة نشر Cloud Functions

## ❌ المشكلة

```
Error: Failed to create function: Unable to retrieve the repository metadata
Ensure that the Cloud Functions service account has 'artifactregistry.repositories.list' and 'artifactregistry.repositories.get' permissions.
```

## ✅ الحل

### الخطوة 1: فتح Google Cloud Console

1. اذهب إلى: https://console.cloud.google.com
2. اختر المشروع: `rideshare-5f785`

### الخطوة 2: إضافة الصلاحيات

#### الطريقة 1: عبر IAM & Admin

1. اذهب إلى: **IAM & Admin** > **IAM**
2. ابحث عن: `rideshare-5f785@appspot.gserviceaccount.com`
3. اضغط على **Edit** (أيقونة القلم)
4. اضغط **ADD ANOTHER ROLE**
5. اختر: **Artifact Registry Reader** (`roles/artifactregistry.reader`)
6. اضغط **SAVE**

#### الطريقة 2: عبر Terminal (أسرع)

```bash
# إضافة الصلاحية
gcloud projects add-iam-policy-binding rideshare-5f785 \
  --member="serviceAccount:rideshare-5f785@appspot.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

**ملاحظة:** إذا لم يكن `gcloud` مثبتاً، استخدم الطريقة 1.

### الخطوة 3: إعادة المحاولة

بعد إضافة الصلاحيات، حاول النشر مرة أخرى:

```bash
firebase deploy --only functions
```

---

## 🔍 التحقق من الصلاحيات

### عبر Google Cloud Console:

1. اذهب إلى: **IAM & Admin** > **IAM**
2. ابحث عن: `rideshare-5f785@appspot.gserviceaccount.com`
3. تأكد من وجود: **Artifact Registry Reader**

### عبر Terminal:

```bash
gcloud projects get-iam-policy rideshare-5f785 \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:rideshare-5f785@appspot.gserviceaccount.com"
```

---

## ⚠️ ملاحظات مهمة

### 1. Billing Account
- ⚠️ تأكد من وجود Billing Account مفعّل
- ⚠️ Cloud Functions تحتاج **Blaze Plan**

### 2. Service Account
- ✅ Service Account موجود تلقائياً: `rideshare-5f785@appspot.gserviceaccount.com`
- ✅ يحتاج فقط إضافة الصلاحيات

### 3. APIs المطلوبة
- ✅ Cloud Functions API (مفعّل)
- ✅ Cloud Build API (مفعّل)
- ✅ Artifact Registry API (مفعّل)
- ✅ Cloud Scheduler API (مفعّل - للـ scheduled functions)

---

## 🚀 بعد إضافة الصلاحيات

بعد إضافة `roles/artifactregistry.reader`، جرب النشر مرة أخرى:

```bash
firebase deploy --only functions
```

يجب أن يعمل الآن! ✅

---

## 📚 مراجع

- [Cloud Functions IAM](https://cloud.google.com/functions/docs/concepts/iam)
- [Artifact Registry Permissions](https://cloud.google.com/artifact-registry/docs/access-control)








