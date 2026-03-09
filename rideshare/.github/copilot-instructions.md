# RideShare Project Instructions

## Architecture & State Management
- **Pattern:** MVVM with BLoC (migrating from Provider).
- **BLoC Layer:** Located in [lib/bloc/](lib/bloc/). Use `flutter_bloc` for state management. States and Events must extend `Equatable`.
- **Data Layer:** 
  - Services in [lib/core/services/](lib/core/services/) handle Firebase and external API interactions.
  - Models in [lib/models/](lib/models/) must include `fromFirestore`, `toFirestore`, and `copyWith` methods.
- **UI Layer:** 
  - Screens in [lib/screens/](lib/screens/) should use `BlocBuilder` and `BlocListener`.
  - Reusable widgets in [lib/widgets/](lib/widgets/).
  - Primary focus is RTL (Arabic) support.

## Key Conventions
- **Constants:** Always use [lib/core/constants/app_constants.dart](lib/core/constants/app_constants.dart) for:
  - Roles: `rolePassenger`, `roleDriver`, `roleAdmin`.
  - Genders: `genderMale`, `genderFemale`.
  - Vehicle Types: `vehicleTypeSedan`, `vehicleTypeSUV`, etc.
- **Internationalization:** Support AR/EN. Use `AppLocalizations` for strings.
- **Gender Rules:** Strictly enforce gender-based seat booking (preventing male next to female) as documented in [docs/USER_GENDER_GUIDE.md](docs/USER_GENDER_GUIDE.md). Use `userModel.isMale` and `userModel.isFemale` getters.
- **User Roles:** Drivers can also act as passengers (book seats in other trips). Check `userModel.isDriver` and `userModel.isPassenger`.
- **Firebase:** 
  - Use Firestore for the database.
  - Use Cloud Functions for sensitive logic (OTP, Payments, Notifications) in [functions/index.js](functions/index.js).
  - Phone verification uses a custom OTP flow via EasySendSMS.

## Developer Workflows
- **Development Mode:** 
  - Toggle `AppConstants.skipOTP = true` in [lib/core/constants/app_constants.dart](lib/core/constants/app_constants.dart) to bypass SMS verification.
  - Use `AppConstants.printOTPToConsole = true` to see OTPs in the debug console.
- **Cloud Functions:** Deploy using `firebase deploy --only functions`.
- **Driver Signup:** Multi-step flow: 1. Basic account creation (`DriverSignUpScreen`), 2. Profile completion (`DriverCompleteProfileScreen`).

## Integration Points
- **Maps:** Google Maps API for location and route visualization.
- **Payments:** Stripe/Paymob integration for driver fees.
- **Notifications:** Firebase Cloud Messaging (FCM) for real-time updates.

## Example Patterns
- **BLoC Usage:**
  ```dart
  context.read<AuthBloc>().add(AuthSignInWithEmail(email: email, password: password));
  ```
- **Firestore Model:**
  ```dart
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      gender: data['gender'] ?? AppConstants.genderMale,
      // ...
    );
  }
  ```
