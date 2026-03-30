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

## Design Context

### Users
RedShare serves everyday commuters and occasional inter-city travelers across Arab communities. Arabic-first (RTL), with English support. Two roles: Drivers and Passengers. Mobile-first, often on-the-go.

### Brand Personality
**Trusted. Simple. Local.** — Confident but approachable, Arabic-first with RTL as default, community-oriented, modern without chasing trends.

### Aesthetic Direction
- **Clean & Minimal** — whitespace-heavy, restrained palette, content breathes
- **Reference:** Uber / Careem — map-centric, professional, confident spacing
- **Anti-reference:** Never Western-only — must respect Arabic/RTL context
- **Primary color:** Teal `#0D9488` — trustworthy, modern, distinct
- **Typography:** Tajawal only. No Cairo, no inline GoogleFonts overrides.
- **Icons:** Iconsax Plus (Linear=inactive, Bold=active)
- **Light + Dark theme** support required
- **Consistent radius scale:** 8, 12, 16, 20, 24 (no one-off values)
- **Subtle shadows:** `black.withOpacity(0.04)`, blur 8-12, offset (0,2-4)

### Design Principles
1. **Trust through clarity** — Clear hierarchy, no ambiguity in trip/pricing info
2. **Arabic-first, not Arabic-after** — RTL is default, Tajawal only
3. **One design system, zero drift** — No hardcoded colors, no inline font overrides. Eliminate purple (#6C63FF) and Tailwind Slate drift.
4. **Speed of task** — Minimize taps to core actions, remove decorative noise
5. **Teal as signal** — Brand teal reserved for primary actions and active states only

### Color Tokens (Target)
| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| primary | `#0D9488` | `#2DD4BF` | CTAs, active tabs, brand accents |
| primaryDark | `#0F766E` | `#14B8A6` | Gradients, pressed states |
| primaryLight | `#99F6E4` | `#134E4A` | Tinted backgrounds |
| secondary | `#F59E0B` | `#FBBF24` | Ratings, warnings, accents |
| success | `#10B981` | `#34D399` | Confirmed, available |
| error | `#EF4444` | `#F87171` | Errors, unavailable |
| background | `#F8FAFC` | `#0F172A` | Scaffold |
| surface | `#FFFFFF` | `#1E293B` | Cards, sheets, inputs |
| textPrimary | `#0F172A` | `#F1F5F9` | Headings, body |
| textSecondary | `#64748B` | `#94A3B8` | Captions, muted |
| border | `#E2E8F0` | `#334155` | Borders, dividers |

### Spacing Scale
xs=4, sm=8, md=12, lg=16, xl=20, xxl=24, xxxl=32

### Border Radius Scale
sm=8, md=12, lg=16, xl=20, xxl=24, full=999
