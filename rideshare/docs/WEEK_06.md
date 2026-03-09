# 📅 الأسبوع السادس: Chat & Ratings

## 🎯 الأهداف

1. Chat System (Per Trip) مع تفعيل بعد دفع السائق لرسوم التواصل
2. Real-time Messaging
3. Masking Rules (إخفاء الأرقام ومنع تبادل أرقام الهواتف)
4. Rating System (5 Stars)
5. Rating Screen
6. Update User Ratings

---

## ✅ Checklist

### Day 1-2: Chat System
- [ ] Chat screen (driver/passenger per trip)
- [ ] Message input
- [ ] Real-time messages
- [ ] Chat list (فقط للرحلات التي تم تفعيل التواصل فيها)

### Day 3-4: Real-time Messaging & Masking
- [ ] Firestore messages collection
- [ ] StreamBuilder for messages
- [ ] Send message
- [ ] Message display
- [ ] Basic masking for phone numbers داخل النص (Regex on client)

### Day 5-6: Rating System
- [ ] Rating screen (5 stars)
- [ ] Optional comment
- [ ] Submit rating
- [ ] Display ratings

### Day 7: Cloud Function
- [ ] Update user rating average
- [ ] Trigger on rating created
- [ ] Test rating updates

---

## 📝 Key Files

- `lib/screens/passenger/chat_screen.dart`
- `lib/screens/driver/chat_screen.dart`
- `lib/widgets/chat_bubble_widget.dart`
- `lib/screens/passenger/rating_screen.dart`
- `lib/widgets/rating_widget.dart`
- `lib/models/chat_model.dart`
- `lib/models/rating_model.dart`
- `functions/rating_functions.js`

---

**Next:** [WEEK_07.md](./WEEK_07.md)


