# 📅 الأسبوع الثالث: Passenger Features

## 🎯 الأهداف

1. Trips List Screen (الرحلات القريبة منك + الفلاتر)
2. Trip Details Screen (مع عرض معلومات الرحلة والسائق)
3. Seat Selection Widget
4. Seat Validation Logic (منع الاختلاط)
5. Booking System (طلب انضمام بمراحل pending/confirmed)

---

## ✅ Checklist

### Day 1-2: Trips List
- [ ] Display nearby active trips based on user location
- [ ] Simple filters (all / inside city / between cities)
- [ ] Change location button
- [ ] Real-time updates

### Day 3-4: Seat Selection
- [ ] Dynamic Seat Layout Widget
- [ ] Gender mixing prevention
- [ ] Visual feedback
- [ ] Seat booking logic

### Day 5: Booking System
- [ ] Create booking request (status = pending)
- [ ] Update trip seats after driver confirms (status = confirmed)
- [ ] Real-time sync
- [ ] Transaction safety
 - [ ] Add option for passenger to toggle sharePhoneWithDriver (show/hide phone number)

### Day 6-7: Trip Details
- [ ] Show trip info
- [ ] Show map
- [ ] Show driver info
- [ ] Book button

---

## 📝 Key Files

- `lib/screens/passenger/trips_list_screen.dart`
- `lib/screens/passenger/trip_details_screen.dart`
- `lib/screens/passenger/seat_selection_screen.dart`
- `lib/widgets/seat_layout_widget.dart`
- `lib/utils/seat_validation.dart`
- `lib/models/booking_model.dart`

---

**Next:** [WEEK_04.md](./WEEK_04.md)


