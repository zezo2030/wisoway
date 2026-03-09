import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_constants.dart';

class LocalizationService extends ChangeNotifier {
  Locale _locale = const Locale(AppConstants.langArabic);
  
  Locale get locale => _locale;
  
  bool get isArabic => _locale.languageCode == AppConstants.langArabic;
  bool get isRTL => isArabic;
  
  LocalizationService() {
    _loadSavedLanguage();
  }
  
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(AppConstants.keyLanguage);
      if (savedLanguage != null) {
        _locale = Locale(savedLanguage);
        // Update Firebase Auth language code
        try {
          await FirebaseAuth.instance.setLanguageCode(savedLanguage);
        } catch (e) {
          // Handle error silently
        }
        notifyListeners();
      }
    } catch (e) {
      // Use default language (Arabic)
    }
  }
  
  Future<void> setLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    
    _locale = Locale(languageCode);
    notifyListeners();
    
    // Update Firebase Auth language code to prevent locale warning
    try {
      await FirebaseAuth.instance.setLanguageCode(languageCode);
    } catch (e) {
      // Handle error silently - Firebase Auth might not be initialized yet
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyLanguage, languageCode);
    } catch (e) {
      // Handle error silently
    }
  }
  
  Future<void> toggleLanguage() async {
    final newLanguage = isArabic 
        ? AppConstants.langEnglish 
        : AppConstants.langArabic;
    await setLanguage(newLanguage);
  }
}

