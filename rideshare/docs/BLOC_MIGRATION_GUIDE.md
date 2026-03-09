# 🔄 دليل التحويل من Provider إلى BLoC

## 📋 نظرة عامة

تم إنشاء BLoC structure. الآن يجب تحديث الشاشات لاستخدام BLoC بدلاً من Provider.

---

## 🔄 أمثلة التحويل

### 1. Sign In Screen

**قبل (Provider):**
```dart
final authProvider = Provider.of<AuthProvider>(context);
await authProvider.signInWithEmailAndPassword(
  email: email,
  password: password,
);
```

**بعد (BLoC):**
```dart
context.read<AuthBloc>().add(
  AuthSignInWithEmail(
    email: email,
    password: password,
  ),
);
```

### 2. Listening to State

**قبل (Provider):**
```dart
Consumer<AuthProvider>(
  builder: (context, authProvider, _) {
    if (authProvider.isLoading) {
      return CircularProgressIndicator();
    }
    if (authProvider.isAuthenticated) {
      return HomeScreen();
    }
    return SignInScreen();
  },
)
```

**بعد (BLoC):**
```dart
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    if (state is AuthLoading) {
      return CircularProgressIndicator();
    }
    if (state is AuthAuthenticated) {
      return HomeScreen();
    }
    return SignInScreen();
  },
)
```

### 3. Listening to Changes

**قبل (Provider):**
```dart
// No direct equivalent - uses notifyListeners()
```

**بعد (BLoC):**
```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
    if (state is AuthAuthenticated) {
      Navigator.pushReplacementNamed(context, RouteNames.home);
    }
  },
  child: ...,
)
```

### 4. Getting Current State

**قبل (Provider):**
```dart
final authProvider = Provider.of<AuthProvider>(context);
final user = authProvider.userModel;
```

**بعد (BLoC):**
```dart
final state = context.read<AuthBloc>().state;
if (state is AuthAuthenticated) {
  final user = state.userModel;
}
```

---

## 📝 قائمة الشاشات التي تحتاج تحديث

### Authentication Screens:
- [ ] `sign_in_screen.dart`
- [ ] `sign_up_screen.dart`
- [ ] `phone_auth_screen.dart`
- [ ] `otp_verification_screen.dart`
- [ ] `profile_setup_screen.dart`
- [ ] `driver_sign_up_screen.dart`
- [ ] `driver_complete_profile_screen.dart`

### Driver Screens:
- [ ] `create_trip_screen.dart`
- [ ] `my_trips_screen.dart`
- [ ] `trip_management_screen.dart`

### Main Screens:
- [x] `main.dart` - ✅ تم التحديث
- [ ] `home_screen.dart`

---

## 🎯 خطوات التحديث لكل شاشة

1. **استبدال imports:**
   ```dart
   // إزالة
   import 'package:provider/provider.dart';
   import '../../providers/auth_provider.dart';
   
   // إضافة
   import 'package:flutter_bloc/flutter_bloc.dart';
   import '../../bloc/auth/auth_bloc.dart';
   import '../../bloc/auth/auth_state.dart';
   ```

2. **استبدال Provider.of بـ context.read:**
   ```dart
   // قبل
   final authProvider = Provider.of<AuthProvider>(context, listen: false);
   
   // بعد
   context.read<AuthBloc>().add(...);
   ```

3. **استبدال Consumer بـ BlocBuilder:**
   ```dart
   // قبل
   Consumer<AuthProvider>(
     builder: (context, authProvider, _) { ... }
   )
   
   // بعد
   BlocBuilder<AuthBloc, AuthState>(
     builder: (context, state) { ... }
   )
   ```

4. **استبدال method calls بـ Events:**
   ```dart
   // قبل
   await authProvider.signInWithEmail(...);
   
   // بعد
   context.read<AuthBloc>().add(
     AuthSignInWithEmail(...),
   );
   ```

5. **إضافة BlocListener للـ side effects:**
   ```dart
   BlocListener<AuthBloc, AuthState>(
     listener: (context, state) {
       // Handle navigation, show snackbars, etc.
     },
     child: ...,
   )
   ```

---

## ✅ مثال كامل: Sign In Screen

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/auth/auth_event.dart';
import '../../core/constants/route_names.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signInWithEmail() {
    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(
      AuthSignInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (state is AuthAuthenticated) {
          Navigator.pushReplacementNamed(context, RouteNames.home);
        }
        if (state is AuthAuthenticatedNoProfile) {
          Navigator.pushReplacementNamed(context, RouteNames.profileSetup);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('تسجيل الدخول')),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                      ),
                      obscureText: true,
                    ),
                    ElevatedButton(
                      onPressed: isLoading ? null : _signInWithEmail,
                      child: isLoading
                          ? const CircularProgressIndicator()
                          : const Text('تسجيل الدخول'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
```

---

## 🚀 الخطوات التالية

1. ✅ إنشاء BLoC structure
2. ✅ تحديث main.dart
3. ⏳ تحديث جميع الشاشات (يمكن القيام بها تدريجياً)
4. ⏳ اختبار التطبيق

---

## 📚 ملاحظات مهمة

- **LocalizationService** يبقى كـ Provider لأنه بسيط ولا يحتاج BLoC
- **StreamBuilder** يمكن استخدامه مع `getDriverTripsStream` في TripBloc
- **BlocProvider.value** يمكن استخدامه عند التنقل بين الشاشات

