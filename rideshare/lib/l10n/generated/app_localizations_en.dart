// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'VisionWay';

  @override
  String get phoneAuth => 'Sign In';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get phoneNumberHint => '+201234567890';

  @override
  String get phoneNumberRequired => 'Please enter phone number';

  @override
  String get sendOTP => 'Send Verification Code';

  @override
  String get otpVerification => 'Verify Code';

  @override
  String get enterOTP => 'Enter verification code';

  @override
  String get resendOTP => 'Resend Code';

  @override
  String resendOTPIn(int seconds) {
    return 'Resend code in $seconds seconds';
  }

  @override
  String get profileSetup => 'Profile Setup';

  @override
  String get name => 'Name';

  @override
  String get nameRequired => 'Please enter name';

  @override
  String get gender => 'Gender';

  @override
  String get genderRequired => 'Please select gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get role => 'Role';

  @override
  String get roleRequired => 'Please select role';

  @override
  String get passenger => 'Passenger';

  @override
  String get driver => 'Driver';

  @override
  String get save => 'Save';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get home => 'Home';

  @override
  String get welcome => 'Welcome';

  @override
  String get signOut => 'Sign Out';

  @override
  String get invalidPhoneNumber => 'Invalid phone number';

  @override
  String get otpSent => 'Verification code sent';

  @override
  String get otpVerified => 'Verified successfully';

  @override
  String get invalidOTP => 'Invalid verification code';

  @override
  String get profileSaved => 'Profile saved successfully';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get darkModeSubtitle => 'Enable dark theme for the app';

  @override
  String get themeMode => 'App Theme';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get currentLanguageAr => 'العربية';

  @override
  String get currentLanguageEn => 'English';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get notificationSound => 'Sound';

  @override
  String get notificationVibration => 'Vibration';

  @override
  String get notificationSettings => 'Detailed Settings';

  @override
  String get notificationSettingsTitle => 'Notification Settings';

  @override
  String get notificationCategories => 'Notification Categories';

  @override
  String get notifTrips => 'Trip Notifications';

  @override
  String get notifPayments => 'Payment Notifications';

  @override
  String get notifMessages => 'Message Notifications';

  @override
  String get notifSystem => 'System Notifications';

  @override
  String get notifCustomizeInfo =>
      'You can customize which notifications you want to receive';

  @override
  String get accountSecurity => 'Account & Security';

  @override
  String get accountInfo => 'Account Info';

  @override
  String get changePassword => 'Change Password';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get accountSecurityTitle => 'Account & Security';

  @override
  String get accountDetails => 'Account Details';

  @override
  String get emailLabel => 'Email';

  @override
  String get phoneLabel => 'Phone Number';

  @override
  String get accountType => 'Account Type';

  @override
  String get linkPhone => 'Link';

  @override
  String get verificationStatus => 'Verification Status';

  @override
  String get emailVerified => 'Email';

  @override
  String get phoneVerified => 'Phone Number';

  @override
  String get driverApproval => 'Driver Approval';

  @override
  String get verified => 'Verified';

  @override
  String get notVerified => 'Not Verified';

  @override
  String get approved => 'Approved';

  @override
  String get pending => 'Pending';

  @override
  String get privacy => 'Privacy';

  @override
  String get locationSharing => 'Location Sharing';

  @override
  String get locationSharingSubtitle => 'Share your live location';

  @override
  String get onlineStatus => 'Online Status';

  @override
  String get onlineStatusSubtitle => 'Show your online status';

  @override
  String get showRating => 'Show Rating';

  @override
  String get showRatingSubtitle => 'Show your rating to others';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacySettings => 'Privacy Settings';

  @override
  String get privacyInfo =>
      'These settings control what others can see about you';

  @override
  String get paymentAndWallet => 'Payment & Wallet';

  @override
  String get wallet => 'Wallet';

  @override
  String get paymentHistory => 'Payment History';

  @override
  String get supportAndHelp => 'Support & Help';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get aboutApp => 'About';

  @override
  String get aboutAppTitle => 'About';

  @override
  String get rateApp => 'Rate App';

  @override
  String get shareApp => 'Share App';

  @override
  String get licenses => 'Licenses';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get appDescription => 'Ride sharing platform';

  @override
  String get madeWithLove => 'Made with ❤️ in Jordan';

  @override
  String get inAppBrowserTitle => 'Browser';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountWarning =>
      'Are you sure you want to delete your account? This action cannot be undone.';

  @override
  String get deleteAccountConfirm => 'Yes, Delete Account';

  @override
  String get deleteAccountSecondWarning =>
      'Final warning: All your data will be permanently deleted and cannot be recovered.';

  @override
  String get deleteAccountSecondConfirm => 'Delete Permanently';

  @override
  String get contactSupportTitle => 'Contact Support';

  @override
  String get contactSupportMessage =>
      'Account deletion is currently unavailable. Please contact support via WhatsApp or email.';

  @override
  String get contactWhatsApp => 'Contact via WhatsApp';

  @override
  String get contactEmail => 'Contact via Email';

  @override
  String get close => 'Close';

  @override
  String get errorsNetworkOffline =>
      'You\'re offline. Check your connection and try again.';

  @override
  String get errorsNetworkTimeout => 'Connection timed out. Please try again.';

  @override
  String get errorsServerGeneric =>
      'Something went wrong on our end. Please try again later.';

  @override
  String get errorsAuthSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorsAuthInvalidCredentials =>
      'Invalid phone number or password.';

  @override
  String get errorsPermissionDenied =>
      'Permission denied. Check your app settings.';

  @override
  String get errorsValidationGeneric =>
      'Invalid input. Please check your data and try again.';

  @override
  String get errorsUnknownGeneric =>
      'An unexpected error occurred. Please try again.';

  @override
  String get errorsActionRetry => 'Retry';

  @override
  String get errorsActionReauthenticate => 'Sign in again';

  @override
  String get errorsActionOpenSettings => 'Open Settings';

  @override
  String get errorsRouteUnavailable =>
      'We couldn\'t load the route. Showing pickup and drop-off points.';

  @override
  String get notificationsBookingCreatedTitle => 'New Booking';

  @override
  String get notificationsBookingCreatedBody =>
      'A new seat was booked on your trip';

  @override
  String get notificationsBookingConfirmedTitle => 'Booking Confirmed';

  @override
  String get notificationsBookingConfirmedBody =>
      'Your booking has been confirmed';

  @override
  String get notificationsBookingRejectedTitle => 'Booking Rejected';

  @override
  String get notificationsBookingRejectedBody =>
      'Unfortunately, your booking was rejected';

  @override
  String get notificationsBookingCanceledTitle => 'Booking Cancelled';

  @override
  String get notificationsBookingCanceledBody =>
      'Your booking has been cancelled';

  @override
  String get notificationsNewTripPostedTitle => 'New Trip Posted';

  @override
  String notificationsNewTripPostedBody(String destination) {
    return 'A new trip to $destination is available';
  }

  @override
  String get accountBannedTitle => 'Account Suspended';

  @override
  String accountBannedMessage(String reason) {
    return 'Your account has been suspended. Reason: $reason';
  }

  @override
  String get accountBannedContactSupport => 'Contact Support';

  @override
  String get accountRestrictedBanner =>
      'Your account is temporarily restricted. Some actions are unavailable pending review.';

  @override
  String get maskedPhoneLabel => 'Hidden number';

  @override
  String get maskedPhoneHint => 'Revealed after payment is confirmed';

  @override
  String get shareLinkTripEnded => 'Trip ended';

  @override
  String get shareLinkLiveTracking => 'Live tracking';

  @override
  String get shareLinkGenerate => 'Share trip';

  @override
  String get noShowNotificationTitle => 'Driver did not arrive';

  @override
  String get noShowNotificationBody =>
      'The driver did not start the trip in time. The trip has been cancelled and a penalty has been applied.';

  @override
  String pendingChargeBanner(String amount) {
    return 'You have an outstanding charge of $amount. It will be collected on your next confirmed booking.';
  }

  @override
  String get pendingChargeTitle => 'Pending Charges';

  @override
  String get pendingChargeKindPassengerCancellation => 'Late cancellation fee';

  @override
  String get pendingChargeKindDriverNoShow => 'Driver no-show penalty';

  @override
  String get pendingChargeKindPassengerNoShow => 'Passenger no-show penalty';

  @override
  String get devicesScreenTitle => 'Connected Devices';

  @override
  String get devicesRevokeButton => 'Remove device';

  @override
  String get devicesCurrentDevice => 'This device';

  @override
  String get bookingTimeoutNotificationTitle => 'Booking expired';

  @override
  String get bookingTimeoutNotificationBody =>
      'Your booking timed out and was not accepted by the driver. The seats are now available.';

  @override
  String get settlementMarkPaid => 'Confirm payment';

  @override
  String get settlementUnmarkPaid => 'Undo payment confirmation';

  @override
  String settlementGraceCountdown(int seconds) {
    return 'Can undo within $seconds seconds';
  }

  @override
  String get chatDisabledUnsettled =>
      'Chat available after payment is confirmed';

  @override
  String get callDisabledUnsettled =>
      'Calling available after payment is confirmed';

  @override
  String get callMaskedNumber => 'Calling via masked number';

  @override
  String get hidePhoneNumberToggle => 'Hide my phone number';

  @override
  String get hidePhoneNumberSubtitle =>
      'Calls will be routed through a proxy number';

  @override
  String get complaintScreenTitle => 'File a Complaint';

  @override
  String get complaintCategoryLabel => 'Complaint type';

  @override
  String get complaintDescriptionLabel => 'Describe the issue';

  @override
  String get complaintSubmitButton => 'Submit complaint';

  @override
  String get complaintSubmittedSuccess =>
      'Your complaint was submitted successfully. We will review it shortly.';

  @override
  String get complaintStatusResolved => 'Resolved';

  @override
  String get refundRequestTitle => 'Request a Refund';

  @override
  String get refundRequestBody =>
      'WhatsApp will open to connect you with our support team about your refund.';

  @override
  String get refundRequestButton => 'Submit refund request';

  @override
  String get supportScreenTitle => 'Support & Help';

  @override
  String get supportWhatsAppButton => 'Chat on WhatsApp';

  @override
  String get tripStopsLabel => 'Stops';

  @override
  String get tripNotesLabel => 'Trip notes';

  @override
  String get tripRecurrenceLabel => 'Repeat trip';

  @override
  String get recurrenceFrequencyDaily => 'Daily';

  @override
  String get recurrenceFrequencyWeekly => 'Weekly';

  @override
  String get recurrenceUntilLabel => 'Until date';

  @override
  String get companionPickerTitle => 'Add companions';

  @override
  String get companionDisplayNameLabel => 'Companion name';

  @override
  String get autoPickSeatsButton => 'Auto-pick seats';

  @override
  String get preTripPromptTitle => 'Confirm presence';

  @override
  String get preTripPromptPassengerBody => 'Is the driver at the pickup point?';

  @override
  String preTripPromptDriverBody(String name) {
    return 'Is passenger $name present?';
  }

  @override
  String get arrivedAtDestinationButton => 'Arrived at destination';

  @override
  String get markPassengerAbsent => 'Mark as absent';

  @override
  String get welcomeTitle => 'Welcome to VisionWay';

  @override
  String get welcomeSubtitle =>
      'Your journey starts here. Pick a destination and travel safely and comfortably.';

  @override
  String get signIn => 'Sign in';

  @override
  String get createNewAccount => 'Create a new account';

  @override
  String get signInSubtitle => 'Welcome back! Sign in to continue.';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get passwordTooShort => 'Password is too short';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get noAccountQuestion => 'Don\'t have an account? ';

  @override
  String get phoneNumberFirst => 'Please enter your phone number first';

  @override
  String get passwordResetLinkSent => 'A password reset link has been sent';

  @override
  String get required => 'Required';

  @override
  String get accountTypePassenger => 'Passenger';

  @override
  String get accountTypeDriver => 'Driver';

  @override
  String get accountTypeTitle => 'Choose account type';

  @override
  String get accountTypeSubtitle => 'Select how you want to use the app';

  @override
  String get accountTypePassengerDesc => 'Easily book a ride';

  @override
  String get accountTypeDriverDesc => 'List your trips for riders';

  @override
  String get continueLabel => 'Continue';

  @override
  String get signUpTitle => 'Create account';

  @override
  String get signUpSubtitle => 'Sign up to get started';

  @override
  String get fullName => 'Full name';

  @override
  String get fullNameRequired => 'Name is required';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get phoneAuthTitle => 'Confirm phone number';

  @override
  String get phoneAuthSubtitle => 'We\'ll send a verification code by SMS';

  @override
  String get linkPhoneTitle => 'Link phone number';

  @override
  String get linkPhoneSubtitle => 'Confirm your phone number to continue';

  @override
  String get otpScreenTitle => 'Enter verification code';

  @override
  String otpScreenSubtitle(String phone) {
    return 'Enter the code sent to $phone';
  }

  @override
  String get verifyButton => 'Verify';

  @override
  String get didntReceiveCode => 'Didn\'t get the code? ';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your phone and we\'ll send a reset code';

  @override
  String get sendResetCode => 'Send reset code';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordSubtitle => 'Enter the code and your new password';

  @override
  String get newPassword => 'New password';

  @override
  String get resetCode => 'Reset code';

  @override
  String get resetCodeRequired => 'Code is required';

  @override
  String get resetPasswordButton => 'Reset';

  @override
  String get passwordResetSuccess => 'Password changed successfully';

  @override
  String get driverSignUpTitle => 'Driver sign-up';

  @override
  String get driverSignUpSubtitle => 'Start by entering your basic details';

  @override
  String get driverCompleteProfileTitle => 'Complete driver profile';

  @override
  String get driverCompleteProfileSubtitle =>
      'We need a few more details to approve your account';

  @override
  String get vehicleMake => 'Vehicle make';

  @override
  String get vehicleModel => 'Vehicle model';

  @override
  String get vehicleYear => 'Year';

  @override
  String get vehicleColor => 'Color';

  @override
  String get vehiclePlate => 'Plate number';

  @override
  String get vehicleSeats => 'Number of seats';

  @override
  String get licenseNumber => 'Driver\'s license number';

  @override
  String get vehicleMakeRequired => 'Vehicle make is required';

  @override
  String get vehicleModelRequired => 'Vehicle model is required';

  @override
  String get vehicleYearRequired => 'Year is required';

  @override
  String get vehicleColorRequired => 'Color is required';

  @override
  String get vehiclePlateRequired => 'Plate number is required';

  @override
  String get vehicleSeatsRequired => 'Number of seats is required';

  @override
  String get licenseNumberRequired => 'License number is required';

  @override
  String get submitButton => 'Submit';

  @override
  String get driverPendingApprovalTitle => 'Your account is under review';

  @override
  String get driverPendingApprovalBody =>
      'We\'ll review your details and notify you once approved. Meanwhile, you can use the app as a passenger.';

  @override
  String get driverPendingApprovalAction => 'Continue as passenger';

  @override
  String get homeTitle => 'Home';

  @override
  String get tripsTab => 'Trips';

  @override
  String get bookingsTab => 'My bookings';

  @override
  String get searchTab => 'Search';

  @override
  String get profileTab => 'Profile';

  @override
  String get myTripsTitle => 'My trips';

  @override
  String get createTripTitle => 'Create trip';

  @override
  String get editTripTitle => 'Edit trip';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get departureDate => 'Departure date';

  @override
  String get departureTime => 'Departure time';

  @override
  String get pricePerSeat => 'Price per seat';

  @override
  String get availableSeats => 'Available seats';

  @override
  String get notes => 'Notes';

  @override
  String get createTripButton => 'Create trip';

  @override
  String get saveChangesButton => 'Save changes';

  @override
  String get cancelTripButton => 'Cancel trip';

  @override
  String get startTripButton => 'Start trip';

  @override
  String get completeTripButton => 'Complete trip';

  @override
  String get tripCreated => 'Trip created successfully';

  @override
  String get tripUpdated => 'Trip updated';

  @override
  String get tripCanceled => 'Trip canceled';

  @override
  String get tripStarted => 'Trip started';

  @override
  String get tripCompleted => 'Trip completed';

  @override
  String get noTripsYet => 'No trips yet';

  @override
  String get noBookingsYet => 'No bookings yet';

  @override
  String get searchTripsHint => 'Search for a trip...';

  @override
  String get bookSeatButton => 'Book a seat';

  @override
  String get selectSeats => 'Select seats';

  @override
  String get selectedSeats => 'Selected seats';

  @override
  String get totalPrice => 'Total';

  @override
  String get confirmBooking => 'Confirm booking';

  @override
  String get bookingConfirmed => 'Booking confirmed';

  @override
  String get viewTripDetails => 'Trip details';

  @override
  String get tripDetailsTitle => 'Trip details';

  @override
  String get passengersLabel => 'Passengers';

  @override
  String get driverLabel => 'Driver';

  @override
  String get vehicleLabel => 'Vehicle';

  @override
  String get departureLabel => 'Departure';

  @override
  String get arrivalLabel => 'Arrival';

  @override
  String get priceLabel => 'Price';

  @override
  String get statusLabel => 'Status';

  @override
  String get callDriver => 'Call driver';

  @override
  String get chatWithDriver => 'Chat with driver';

  @override
  String get rateDriver => 'Rate driver';

  @override
  String get rateTrip => 'Rate the trip';

  @override
  String get submitRating => 'Submit rating';

  @override
  String get ratingSubmitted => 'Rating submitted';

  @override
  String get shareRideButton => 'Share ride';

  @override
  String get trackRideButton => 'Track ride';

  @override
  String get startNow => 'Start now';

  @override
  String get phoneNumberRequired2 => 'Enter phone number';

  @override
  String get verifyOtpTitle => 'Verify phone number';

  @override
  String get otpSentTo => 'We sent a verification code to';

  @override
  String resendCodeIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String get verifyAndContinue => 'Verify & continue';

  @override
  String get changeNumber => 'Change number';

  @override
  String get personalInfoTitle => 'Personal details';

  @override
  String get vehicleInfoTitle => 'Vehicle details';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get uploadIdFront => 'ID photo - front';

  @override
  String get uploadIdBack => 'ID photo - back';

  @override
  String get uploadLicense => 'Driver\'s license photo';

  @override
  String get uploadVehicleRegistration => 'Vehicle registration photo';

  @override
  String get uploadProfilePhoto => 'Profile photo';

  @override
  String get uploadingFile => 'Uploading...';

  @override
  String get tapToUpload => 'Tap to upload';

  @override
  String get tapToChange => 'Tap to change';

  @override
  String get complete => 'Complete';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get skip => 'Skip';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String get copy => 'Copy';

  @override
  String get search => 'Search';

  @override
  String get tryAgain => 'Try again';

  @override
  String get logoutButton => 'Sign out';

  @override
  String get logoutConfirmTitle => 'Confirm sign out';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to sign out?';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String get clearAll => 'Clear all';

  @override
  String signUpAs(String role) {
    return 'Sign up as a $role to start your journey with us.';
  }

  @override
  String get fullNameHint => 'Enter your full name';

  @override
  String get validNameRequired => 'Please enter a valid name';

  @override
  String get passwordHint => 'At least 8 characters with a letter and a number';

  @override
  String get passwordPolicyError =>
      'Password must be 8+ chars with a letter and a number';

  @override
  String get confirmPasswordHint => 'Re-enter your password';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get createAccountDev => 'Create account (dev)';

  @override
  String get sendOtpAndCreateAccount => 'Send OTP and create account';

  @override
  String get selectGenderError => 'Please select gender';

  @override
  String get couldNotOpenWhatsApp => 'Could not open WhatsApp';

  @override
  String get contactSupportViaWhatsApp => 'Contact support via WhatsApp';

  @override
  String get pickImageFromGallery => 'Pick an image from the gallery';

  @override
  String get captureImageFromCamera => 'Capture an image from the camera';

  @override
  String get fromGallery => 'From gallery';

  @override
  String get fromCamera => 'From camera';

  @override
  String get driverProfileSubmittedFull =>
      'Your details were uploaded successfully. Your request is under review by the administration; you will be approved soon and can create trips after approval.';

  @override
  String get driverProfileSubmitted =>
      'Your details were uploaded successfully. Your request is under review by the administration.';

  @override
  String get driverProfileStep2 => 'Step 2 of 2: Additional information';

  @override
  String get profilePhotoRequired => 'Profile photo *';

  @override
  String get vehicleType => 'Vehicle type';

  @override
  String get vehicleTypeRequired => 'Vehicle type *';

  @override
  String get vehicleTypeValidation => 'Please select a vehicle type';

  @override
  String get vehiclePlateRequiredLabel => 'Plate number *';

  @override
  String get vehicleModelRequiredLabel => 'Car model *';

  @override
  String get vehicleSeatsRequiredLabel => 'Number of seats *';

  @override
  String get vehicleSeatsInvalid =>
      'The number of seats must be a whole number greater than 0';

  @override
  String get driverLicenseRequired => 'Driver license *';

  @override
  String get vehicleLicenseRequired => 'Vehicle license *';

  @override
  String get carPhotoRequired => 'Car photo *';

  @override
  String uploadFileLabel(String title) {
    return 'Upload $title';
  }

  @override
  String get firstName => 'First name';

  @override
  String get firstNameHint => 'Ahmed';

  @override
  String get lastName => 'Last name';

  @override
  String get lastNameHint => 'Ali';

  @override
  String get driverSignUpVerifyButton =>
      'Verify phone number and create password';

  @override
  String get driverSignUpStep1 =>
      'Step 1 of 3: Basic information and verification';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get otpResent => 'Verification code resent';

  @override
  String get otpSentToPhone => 'A 6-digit code has been sent to\n';

  @override
  String otpDigitLabel(int index) {
    return 'Verification code digit $index';
  }

  @override
  String get enterPhoneToConfirm => 'Enter your phone number to confirm';

  @override
  String get enterYourPhone => 'Enter your phone number';

  @override
  String get devModeDirectLogin =>
      'Development mode: you will be logged in directly';

  @override
  String get otpWillBeSentViaSms =>
      'We will send you a verification code via SMS';

  @override
  String get enterAction => 'Enter';

  @override
  String get emailHint => 'example@email.com';

  @override
  String selectedRoleLabel(String role) {
    return 'You selected the role: $role';
  }

  @override
  String get passengerDescription => 'Find trips and book your seat';

  @override
  String get tripOwnerDescription => 'Create trips and offer your seats';

  @override
  String get tripOwnerNote =>
      'You will need to complete your vehicle details and documents for your driver account to be approved.';

  @override
  String get saveAndComplete => 'Save and complete';

  @override
  String get profileSetupSubtitle => 'Complete your details to continue';

  @override
  String get otpTooManyAttempts =>
      'Too many attempts. Please request a new code.';

  @override
  String get otpExpired =>
      'Verification code has expired. Please request a new one.';

  @override
  String get requestNewCode => 'Request New Code';

  @override
  String get newOtpSent => 'A new verification code has been sent';

  @override
  String waitBeforeResend(int seconds) {
    return 'Please wait $seconds seconds before requesting a new code';
  }

  @override
  String get otpSentToYourPhone =>
      'A verification code has been sent to your phone number';

  @override
  String get newPasswordRequired => 'Please enter a new password';

  @override
  String get yourProfile => 'Your profile';

  @override
  String get notSpecified => 'Not specified';

  @override
  String get viewProfile => 'View profile';

  @override
  String get userFallback => 'User';

  @override
  String get browseTrips => 'Browse trips';

  @override
  String get myWallet => 'My wallet';

  @override
  String get pendingChargesTitle => 'Pending charges';

  @override
  String get profileTitle => 'Profile';

  @override
  String get locationServicesDisabledTitle => 'Location services disabled';

  @override
  String get locationServicesDisabledMessage =>
      'Please enable location services (GPS) to use the app and share your location.';

  @override
  String get enable => 'Enable';

  @override
  String get locationPermissionRequiredTitle => 'Location permission required';

  @override
  String get locationPermissionRequiredMessage =>
      'The app needs location access permission so you can share your trips.';

  @override
  String get grantPermission => 'Grant permission';

  @override
  String get later => 'Later';

  @override
  String get chooseYourLocation => 'Choose your location';

  @override
  String get defaultCityName => 'Amman';

  @override
  String get defaultCityAddress => 'Amman, Jordan';

  @override
  String get myBookings => 'My bookings';

  @override
  String get profileTabLabel => 'Profile';

  @override
  String get createNewTrip => 'Create new trip';

  @override
  String get mustSignIn => 'You must sign in';

  @override
  String get noBookingsCurrently => 'No bookings currently';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get cannotCancel => 'Cannot cancel';

  @override
  String cannotCancelWithin12Hours(String departure) {
    return 'You cannot cancel the booking within 12 hours of the trip time.\n\nTrip time: $departure';
  }

  @override
  String get unknown => 'Unknown';

  @override
  String get confirmCancelBooking => 'Confirm booking cancellation';

  @override
  String get cancellationFeeNotice =>
      'A 5% cancellation fee of your booking value will be deducted and applied to your next trip.';

  @override
  String get confirmCancelBookingQuestion =>
      'Are you sure you want to cancel the booking?';

  @override
  String get goBack => 'Go back';

  @override
  String get cancelBooking => 'Cancel booking';

  @override
  String get bookingCancelledSuccess => 'Booking cancelled successfully';

  @override
  String get noTripsTitle => 'No trips';

  @override
  String get noTripsSubtitle =>
      'Start by creating a new trip and share\nyour journey with others';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get openMenu => 'Open menu';

  @override
  String get sideMenu => 'Side menu';

  @override
  String get whereWillYourTripStart => 'Where will your trip start?';

  @override
  String get createTripCtaSubtitle =>
      'Start your trip and receive bookings from passengers';

  @override
  String get currentLocation => 'Your current location';

  @override
  String get determiningLocation => 'Determining location...';

  @override
  String get detectLocationAutomatically => 'Detect location automatically';

  @override
  String get chooseLocationManually => 'Choose location manually';

  @override
  String get myActiveTrips => 'My active trips';

  @override
  String get errorLoadingTrips => 'Error loading trips';

  @override
  String get noActiveTripsTitle => 'No active trips';

  @override
  String get noActiveTripsSubtitle =>
      'Start by creating a trip to see it here.';

  @override
  String get whereDoYouWantToGo => 'Where do you want to go?';

  @override
  String get haveAPlaceInMind => 'Have a place in mind?';

  @override
  String get nearbyTrips => 'Trips near you';

  @override
  String get viewAll => 'View all';

  @override
  String get noNearbyTripsTitle => 'No nearby trips';

  @override
  String get noNearbyTripsSubtitle =>
      'Try changing your location or view all trips';

  @override
  String get viewAllTrips => 'View all trips';

  @override
  String showMoreTrips(int count) {
    return 'Show $count more trips';
  }

  @override
  String get dataUpdated => 'Data updated';

  @override
  String dataUpdateFailed(String error) {
    return 'Failed to update data: $error';
  }

  @override
  String get refreshData => 'Refresh data';

  @override
  String get driverDataApproved => 'Your data has been approved';

  @override
  String get driverAccountUnderReview => 'Your driver account is under review';

  @override
  String get driverApprovedDescription =>
      'You can create and manage trips from the \"My trips\" tab.';

  @override
  String get driverPendingDescription =>
      'You cannot create trips until your data is approved by the administration. You can currently book as a passenger.';

  @override
  String get checkVerificationStatus => 'Check verification status';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get helpAndSupport => 'Help and support';

  @override
  String get searchForTrip => 'Search for a trip';

  @override
  String get showAllAvailableTrips => 'Show all available trips';

  @override
  String get showTrips => 'Show trips';

  @override
  String get completedTrip => 'Completed trip';

  @override
  String get tripUnavailable => 'Trip unavailable';

  @override
  String get bookingStatusPending => 'Pending';

  @override
  String get bookingStatusConfirmed => 'Confirmed';

  @override
  String get bookingStatusCancelled => 'Cancelled';

  @override
  String get dateLabel => 'Date';

  @override
  String get timeLabel => 'Time';

  @override
  String get seatLabel => 'Seat';

  @override
  String get chat => 'Chat';

  @override
  String get call => 'Call';

  @override
  String distanceKm(String distance) {
    return '$distance km';
  }

  @override
  String get tripStatusActive => 'Active';

  @override
  String get tripStatusFullyBooked => 'Fully booked';

  @override
  String get tripStatusInProgress => 'In progress';

  @override
  String get tripStatusHidden => 'Hidden';

  @override
  String seatsAvailable(int count) {
    return '$count available';
  }

  @override
  String get feePaid => 'Paid';

  @override
  String get feeDue => 'Due';

  @override
  String get tripStartDeadlinePassed =>
      'Trip start time has passed (the driver did not start within the deadline)';

  @override
  String get homeGreeting => 'Welcome';

  @override
  String get defaultUserName => 'User';

  @override
  String get homeStartTripTitle => 'Start your trip';

  @override
  String get homeStartTripSubtitle => 'Create a new trip and earn money';

  @override
  String get homeCreateTripButton => 'Create a new trip';

  @override
  String get userInfoTitle => 'User information';

  @override
  String get roleLabel => 'Role';

  @override
  String get statisticsTitle => 'Statistics';

  @override
  String get tripsStatLabel => 'Trips';

  @override
  String get passengersStatLabel => 'Passengers';

  @override
  String get editProfilePhoto => 'Edit profile photo';

  @override
  String get phoneNotVerified => 'Phone number not verified';

  @override
  String get editProfileMenuItem => 'Edit profile';

  @override
  String get logout => 'Log out';

  @override
  String get locationUnavailable => 'Could not get location.';

  @override
  String get locationServicesDisabled => 'Location services are disabled.';

  @override
  String get enableAction => 'Enable';

  @override
  String get locationPermissionRequired => 'Location permission is required.';

  @override
  String get grantAction => 'Grant';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Permission was permanently denied.';

  @override
  String filterFromValue(String value) {
    return 'From: $value';
  }

  @override
  String filterToValue(String value) {
    return 'To: $value';
  }

  @override
  String filterCityValue(String value) {
    return 'City: $value';
  }

  @override
  String filterDateValue(String value) {
    return 'Date: $value';
  }

  @override
  String get filterSortNewest => 'Sort: Newest';

  @override
  String get availableTripsTitle => 'Available trips';

  @override
  String get signInToViewTrips => 'You must sign in to view trips';

  @override
  String get changeLocation => 'Change location';

  @override
  String get filterAndSort => 'Filter and sort';

  @override
  String get currentLocationLabel => 'Your current location:';

  @override
  String get detectingLocation => 'Detecting location...';

  @override
  String get preferredTrips => 'Preferred trips';

  @override
  String get allTrips => 'All trips';

  @override
  String errorWithDetail(String detail) {
    return 'Error: $detail';
  }

  @override
  String get enableLocationForTrips => 'Enable location to view these trips';

  @override
  String get noTripsAvailable => 'No trips available';

  @override
  String get chooseLocationThenRetry =>
      'Choose your current location then try again';

  @override
  String get tryChangingFilterOrLocation =>
      'Try changing the filter or location';

  @override
  String get refreshTripsList => 'Refresh trips list';

  @override
  String get refresh => 'Refresh';

  @override
  String get filterAndSortTrips => 'Filter and sort trips';

  @override
  String get chooseDeparturePoint => 'Choose departure point';

  @override
  String get chooseDestination => 'Choose destination';

  @override
  String get cityLabel => 'City';

  @override
  String get searchByCityName => 'Search by city name';

  @override
  String get chooseDate => 'Choose date';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortNearest => 'Nearest';

  @override
  String get sortNewest => 'Newest';

  @override
  String get apply => 'Apply';

  @override
  String tripDetailsFromTo(String from, String to) {
    return 'Trip details from $from to $to';
  }

  @override
  String get liveDriverLocation => 'Live driver location';

  @override
  String get tripNotFound => 'Trip not found';

  @override
  String get tripRouteTitle => 'Trip route';

  @override
  String get viewRouteOnMap => 'View route on map';

  @override
  String get tripDistanceLabel => 'Trip distance';

  @override
  String distanceKmValue(String value) {
    return '$value km';
  }

  @override
  String get departureTimeLabel => 'Departure time';

  @override
  String seatsCountOfTotal(int available, int total) {
    return '$available of $total';
  }

  @override
  String get seatLayoutLabel => 'Seat layout';

  @override
  String get preventGenderMixingLabel => 'Prevent gender mixing';

  @override
  String get enabledValue => 'Enabled';

  @override
  String get driverInfoTitle => 'Driver information';

  @override
  String get carImageTitle => 'Car image';

  @override
  String get noSeatsAvailable => 'No seats available';

  @override
  String get chatLabel => 'Chat';

  @override
  String get chatNotEnabledYet =>
      'Communication is not enabled yet. The driver must pay the communication fee first.';

  @override
  String get rateLabel => 'Rate';

  @override
  String get alreadyRatedTrip => 'You have already rated this trip';

  @override
  String get thanksForRating => 'Thank you for your rating!';

  @override
  String get canRateAfterTripEnds => 'You can rate after the trip ends';

  @override
  String get seatNotSelectable =>
      'This seat cannot be selected; it may be reserved or unsuitable according to the trip rules.';

  @override
  String get signInRequired => 'You must sign in';

  @override
  String get tripInfoTitle => 'Trip information';

  @override
  String fromValue(String value) {
    return 'From: $value';
  }

  @override
  String toValue(String value) {
    return 'To: $value';
  }

  @override
  String pricePerSeatValue(String price, String currency) {
    return 'Price: $price $currency per seat';
  }

  @override
  String get selectOneOrMoreSeats =>
      'You can select one or more seats depending on availability.';

  @override
  String get enterPassengerDataAfterSeats =>
      'After selecting seats, you will enter each passenger\'s details before sending the booking request.';

  @override
  String get appShareWalletNotice =>
      'The app share will be deducted from your wallet when you submit the booking. Make sure you have enough balance on the My Wallet page.';

  @override
  String selectedSeatsValue(String seats) {
    return 'Selected seats: $seats';
  }

  @override
  String get continueToPassengerData => 'Continue to passenger details';

  @override
  String get continueToPassengerDataTooltip =>
      'Continue to enter passenger details and send the booking request';

  @override
  String get continueBookOneSeat => 'Continue to book one seat';

  @override
  String continueBookSeats(int count) {
    return 'Continue to book $count seats';
  }

  @override
  String get bookingRequestSentNotice =>
      'The booking request will be sent to the driver after confirming passenger details. Wait for the driver\'s approval before the booking is confirmed.';

  @override
  String get departurePointTitle => 'Departure point';

  @override
  String get arrivalPointTitle => 'Arrival point';

  @override
  String get destinationTitle => 'Destination';

  @override
  String get driverLocationTitle => 'Driver location';

  @override
  String get viewFullRoute => 'View full route';

  @override
  String get loadingRouteLabel => 'Loading route';

  @override
  String get loadingRoute => 'Loading route...';

  @override
  String get stopFollowingDriver => 'Stop following driver';

  @override
  String get followDriver => 'Follow driver';

  @override
  String get liveTrackingEnabled => 'Live tracking enabled';

  @override
  String get bookingRequestSentWaitConfirm =>
      'Booking request sent. Wait for the driver\'s confirmation.';

  @override
  String get autoPickTitle => 'Auto pick';

  @override
  String get passengerDataTitle => 'Passenger details';

  @override
  String get seatCountLabel => 'Number of seats';

  @override
  String get mainBookerLabel => 'Main booker';

  @override
  String companionLabel(int index) {
    return 'Companion $index';
  }

  @override
  String get sharePhoneWithDriver => 'Share phone number with driver';

  @override
  String get sharePhoneWithDriverSubtitle =>
      'Allow the driver to see your number for contact';

  @override
  String get sendBookingRequest => 'Send booking request';

  @override
  String get seatWord => 'seat';

  @override
  String get chatClosedForSending =>
      'The trip has ended, and new messages cannot be sent.';

  @override
  String get errorMustSignInFirst => 'You must sign in first';

  @override
  String chatLoadError(String error) {
    return 'Error loading chat: $error';
  }

  @override
  String chatTitleWithDriver(String driverName) {
    return 'Chat - $driverName';
  }

  @override
  String get chatLoadErrorShort => 'Error loading chat';

  @override
  String errorWithMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get chatNoMessagesYet => 'No messages yet';

  @override
  String get chatStartConversationNow => 'Start the conversation now';

  @override
  String get chatTypeMessageLabel => 'Type a message';

  @override
  String get chatTypeMessageHint => 'Type a message...';

  @override
  String get chatSendMessageTooltip => 'Send message';

  @override
  String get complaintCategorySafety => 'Safety';

  @override
  String get complaintCategoryPayment => 'Payment';

  @override
  String get complaintCategoryVehicleCondition => 'Vehicle condition';

  @override
  String get complaintCategoryDriverBehavior => 'Driver behavior';

  @override
  String get complaintCategoryAppIssue => 'App issue';

  @override
  String get complaintCategoryOther => 'Other';

  @override
  String get complaintSubmittedSuccessMessage =>
      'Your complaint has been submitted successfully. We will review it as soon as possible.';

  @override
  String get complaintHeroTitle => 'Tell us what happened';

  @override
  String get complaintHeroSubtitle =>
      'Your complaint helps us improve the service and ensure everyone\'s safety.';

  @override
  String get complaintTypeLabel => 'Complaint type';

  @override
  String get complaintProblemDescriptionLabel => 'Problem description';

  @override
  String get complaintDescriptionHint =>
      'Describe the problem in enough detail to help us review it…';

  @override
  String get complaintDescriptionRequired =>
      'Please write a description of the problem';

  @override
  String get complaintDescriptionTooShort =>
      'Description is too short (at least 10 characters)';

  @override
  String get walletMyWallet => 'My wallet';

  @override
  String get walletTopUpDescription =>
      'Used to pay the booking cost when wallet payment is enabled. Top up in Jordanian Dinar (JOD) via CliQ or manual transfer with proof; the balance is added after confirmation or admin approval depending on the method.';

  @override
  String get walletTransactionHistory => 'Transaction history';

  @override
  String get walletTopUp => 'Top up';

  @override
  String get walletTopUpSemantics => 'Top up wallet';

  @override
  String get walletNoTransactionsYet => 'No transactions yet';

  @override
  String get walletPendingChargesTitle => 'Outstanding charges';

  @override
  String get walletPendingChargesSubtitle =>
      'View pending fines and charges and top up the wallet';

  @override
  String get walletBalanceLabel => 'Wallet balance';

  @override
  String get walletAccountInactive => 'Account is inactive — contact support';

  @override
  String get walletTxTopup => 'Top up';

  @override
  String get walletTxTripPayment => 'Trip payment';

  @override
  String get walletTxTripDebit => 'Trip debit';

  @override
  String get walletTxRefund => 'Refund';

  @override
  String get walletTxPayout => 'Earnings payout';

  @override
  String get walletTxAdjustment => 'Balance adjustment';

  @override
  String get walletTxHold => 'Amount hold';

  @override
  String get walletTxReleaseHold => 'Release hold';

  @override
  String get ratingPleaseSelectRating => 'Please select a rating';

  @override
  String get ratingAlreadyRated => 'You have already rated this trip';

  @override
  String get ratingSubmittedSuccess => 'Rating submitted successfully';

  @override
  String get ratingTripTitle => 'Rate trip';

  @override
  String get ratingHowWasExperience =>
      'How was your experience with the driver?';

  @override
  String get ratingCommentLabel => 'Comment field';

  @override
  String get ratingCommentHint => 'Share your thoughts about the trip';

  @override
  String get ratingCommentOptional => 'Comment (optional)';

  @override
  String get ratingCommentHintEllipsis =>
      'Share your thoughts about the trip...';

  @override
  String get ratingSubmitButton => 'Submit rating';

  @override
  String get ratingLabelVeryBad => 'Very bad';

  @override
  String get ratingLabelBad => 'Bad';

  @override
  String get ratingLabelAverage => 'Average';

  @override
  String get ratingLabelGood => 'Good';

  @override
  String get ratingLabelExcellent => 'Excellent';

  @override
  String get refundSubmittedSuccess =>
      'Your refund request has been recorded. You will be redirected to WhatsApp to complete the procedure.';

  @override
  String get refundRequestScreenTitle => 'Refund request';

  @override
  String get refundHeroTitle => 'Booking fee refund';

  @override
  String refundTripRef(String tripRef) {
    return 'Trip: $tripRef';
  }

  @override
  String get refundContactViaWhatsApp =>
      'Our team will contact you via WhatsApp to complete the procedure.';

  @override
  String get refundReasonLabel => 'Refund request reason';

  @override
  String get refundReasonHint =>
      'Briefly explain why you are requesting a refund…';

  @override
  String get refundReasonRequired => 'Please write the reason for the request';

  @override
  String get refundReasonTooShort =>
      'The reason is too short (at least 10 characters)';

  @override
  String get refundWhatsAppNote =>
      'After submitting, a WhatsApp chat with the support team will open to complete the refund procedure.';

  @override
  String get refundSubmitButton => 'Submit request';

  @override
  String get chatClosedTripEnded =>
      'The trip has ended, you can no longer send new messages.';

  @override
  String get mustSignInFirst => 'You must sign in first';

  @override
  String get chatCreateFailed => 'Could not create the chat';

  @override
  String get tripChatTitle => 'Trip Chat';

  @override
  String chatWithPerson(String name) {
    return 'Chat with $name';
  }

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get startChatNow => 'Start the chat now';

  @override
  String get typeMessage => 'Type a message';

  @override
  String get typeMessageHint => 'Type a message...';

  @override
  String get sendMessage => 'Send message';

  @override
  String get send => 'Send';

  @override
  String get selectOriginPoint => 'Select origin point';

  @override
  String get selectDestination => 'Select destination';

  @override
  String get completeLocationAndTimeData =>
      'Please complete the location and time data';

  @override
  String get departureTimeMustBeFuture =>
      'Departure time must be in the future';

  @override
  String get userNotSignedIn => 'User is not signed in';

  @override
  String get tripCreatedSuccess => 'Trip created successfully';

  @override
  String get tripCreateFailed => 'Failed to create trip';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get driverAccountUnderReviewBody =>
      'You cannot create trips until your details are approved by the administration. For now you can browse trips and book as a passenger.';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get createNewTripTitle => 'Create New Trip';

  @override
  String get backLabel => 'Back';

  @override
  String get shareYourNextTrip => 'Share your next trip';

  @override
  String get createTripHeaderSubtitle =>
      'Set your destination and departure time to start sharing your trip with passengers.';

  @override
  String get tripRoute => 'Trip Route';

  @override
  String get whereAreYouNow => 'Where are you now?';

  @override
  String get whereIsYourDestination => 'Where is your destination?';

  @override
  String get departureAndPriceDetails => 'Departure and price details';

  @override
  String get pricePerSeatHint => 'Price per seat';

  @override
  String get enterPrice => 'Enter the price';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String seatsCount(int count) {
    return '$count seats';
  }

  @override
  String get seatLayoutFromSettings =>
      'The seat layout and gender-mixing prevention are taken from your vehicle settings and applied to all your trips.';

  @override
  String get noSeatLayoutSet =>
      'You have not set a seat layout for your vehicle yet — a default layout will be used. Set it from vehicle settings for a more accurate experience.';

  @override
  String get editVehicleSettings => 'Edit vehicle settings';

  @override
  String get confirmAndPublishTrip => 'Confirm and publish trip';

  @override
  String get stopsLabel => 'Stops';

  @override
  String get optionalLabel => 'Optional';

  @override
  String get addStop => 'Add stop';

  @override
  String get stopsHint => 'Add up to 5 intermediate stops along the route.';

  @override
  String deleteStopNumber(int number) {
    return 'Delete stop $number';
  }

  @override
  String selectStopNumber(int number) {
    return 'Select stop $number';
  }

  @override
  String get notesForPassengers => 'Notes for passengers';

  @override
  String get tripNotesHint =>
      'Example: stop at Petra Pharmacy, don\'t be more than 5 minutes late...';

  @override
  String get tripRecurrence => 'Trip recurrence';

  @override
  String enableTripRecurrenceSemantic(String state) {
    return 'Enable trip recurrence: $state';
  }

  @override
  String get recurrenceStateEnabled => 'enabled';

  @override
  String get recurrenceStateDisabled => 'disabled';

  @override
  String get recurrenceDisabledHint =>
      'Enable this option to schedule the trip automatically (daily or weekly).';

  @override
  String get recurrenceDaily => 'Daily';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceDaysLabel => 'Recurrence days';

  @override
  String weekdaySelectedSemantic(String day) {
    return '$day (selected)';
  }

  @override
  String get recurrenceUntilHint => 'Recurrence end date (optional)';

  @override
  String get recurrenceUntilHelp => 'Recurrence end date';

  @override
  String get uploadCarImageFailed => 'Failed to upload car image';

  @override
  String get tripUpdatedSuccess => 'Trip updated successfully';

  @override
  String get tripUpdateFailed => 'Failed to update trip';

  @override
  String get editTripScreenTitle => 'Edit Trip';

  @override
  String get editYourTrip => 'Edit your trip';

  @override
  String get updateTripInfo => 'Update the trip information';

  @override
  String get tripDetailsSection => 'Trip details';

  @override
  String get originPointLabel => 'Origin point';

  @override
  String get originExampleHint => 'Example: Amman';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get destinationExampleHint => 'Example: Alexandria';

  @override
  String get pickDateAndTime => 'Pick date and time';

  @override
  String get priceExampleHint => 'Example: 100';

  @override
  String get selectOriginValidator => 'Please select an origin point';

  @override
  String get selectDestinationValidator => 'Please select a destination';

  @override
  String get selectDepartureTimeValidator => 'Please select a departure time';

  @override
  String get enterPriceValidator => 'Please enter the price';

  @override
  String get priceMustBeValidPositive =>
      'Price must be a valid number greater than 0';

  @override
  String get carImageSection => 'Car image';

  @override
  String get optionalParen => '(optional)';

  @override
  String get uploadCarImage => 'Upload car image';

  @override
  String get tapToUploadCarImage => 'Tap to upload car image';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get selectFromMap => 'Select from map';

  @override
  String get warningTitle => 'Warning';

  @override
  String get pastDateWarningBody =>
      'You are selecting a date in the past. Past trips will not appear in passenger search results. Do you want to continue?';

  @override
  String bookedSeatsEditWarning(int count) {
    return 'This trip has $count booked seats. Editing some information may affect existing bookings. Do you want to continue?';
  }

  @override
  String get myTripsTitleLabel => 'My Trips';

  @override
  String get driverAccountUnderReviewTrips =>
      'Your driver account is under review. You cannot create or manage trips until it is approved.';

  @override
  String get mustBeApprovedDriver =>
      'You must be an approved driver to view trips.';

  @override
  String get tabActive => 'Active';

  @override
  String get tabHidden => 'Hidden';

  @override
  String get tabCompleted => 'Completed';

  @override
  String get retryLabel => 'Retry';

  @override
  String get noActiveTrips => 'No active trips';

  @override
  String get noHiddenTrips => 'No hidden trips';

  @override
  String get noCompletedTrips => 'No completed trips';

  @override
  String get createTripShort => 'Create trip';

  @override
  String get newTrip => 'New trip';

  @override
  String get createNewTripSemantic => 'Create new trip';

  @override
  String get tripFeeInvoiceTitle => 'Trip Fee Invoice';

  @override
  String get seatPrice => 'Seat price';

  @override
  String get seatsCountLabel => 'Number of seats';

  @override
  String get feePercentage => 'Fee percentage';

  @override
  String get totalLabel => 'Total';

  @override
  String get tripFeeDeductExplanation =>
      'The fee will be deducted from your wallet and the passenger details of this trip will be unlocked. The number of seats or bookings is not changed.';

  @override
  String get payFees => 'Pay fees';

  @override
  String get tripFeePaidSuccess => 'Trip fee paid successfully';

  @override
  String get payingInProgress => 'Paying...';

  @override
  String get unknownLocation => 'Unknown location';

  @override
  String tripFromToSemantic(String from, String to) {
    return 'Trip from $from to $to';
  }

  @override
  String get statusActive => 'Active';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusFullyBooked => 'Fully booked';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusHidden => 'Hidden';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get fromShort => 'From';

  @override
  String get toShort => 'To';

  @override
  String get perSeatSuffix => '/ seat';

  @override
  String get seatsWord => 'seats';

  @override
  String get tripFeePaidLabel => 'Trip fee paid';

  @override
  String get passengerDetailsTitle => 'Passenger Details';

  @override
  String seatLabelWithValue(String seat) {
    return 'Seat $seat';
  }

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String privateChatWithSemantic(String name) {
    return 'Private chat with $name';
  }

  @override
  String get privateChat => 'Private chat';

  @override
  String messagePerson(String name) {
    return 'Message $name';
  }

  @override
  String get confirmFinePayment => 'Confirm fine payment';

  @override
  String amountDue(String amount) {
    return 'Amount due: $amount JOD';
  }

  @override
  String currentWalletBalance(String amount) {
    return 'Current wallet balance: $amount JOD';
  }

  @override
  String balanceAfterPayment(String amount) {
    return 'Balance after payment: $amount JOD';
  }

  @override
  String get confirmAndPay => 'Confirm & pay';

  @override
  String get finePaidSuccess => 'Fine paid from your wallet successfully';

  @override
  String get finePartiallyPaid =>
      'Some charges paid; insufficient balance for the rest';

  @override
  String get insufficientBalanceForFine =>
      'Insufficient wallet balance to pay the charges';

  @override
  String get chargeKindDriverNoShow => 'Driver No-Show';

  @override
  String get chargeKindPassengerNoShow => 'Passenger No-Show';

  @override
  String get chargeKindLateCancellation => 'Late Cancellation';

  @override
  String get chargeStatusPending => 'Pending';

  @override
  String get chargeStatusCollected => 'Collected';

  @override
  String get chargeStatusWaived => 'Waived';

  @override
  String get noOutstandingCharges => 'No outstanding charges';

  @override
  String get accountInGoodStanding => 'Your account is in good standing.';

  @override
  String get cannotPublishUntilSettled =>
      'You can\'t publish a new trip until settled';

  @override
  String totalDue(String amount) {
    return 'Total due: $amount JOD';
  }

  @override
  String walletBalanceAmount(String amount) {
    return 'Wallet balance: $amount JOD';
  }

  @override
  String get balanceEnoughForFine =>
      'Your wallet balance is enough to pay this fine.';

  @override
  String get balanceNotEnoughForFine =>
      'Your balance is not enough — top up your wallet to settle.';

  @override
  String get payFine => 'Pay Fine';

  @override
  String get topUpWallet => 'Top Up Wallet';

  @override
  String amountAmount(String amount) {
    return 'Amount: $amount JOD';
  }

  @override
  String get walletTitle => 'Wallet';

  @override
  String get pleaseSignIn => 'Please sign in';

  @override
  String get txTypeTopup => 'Wallet top-up';

  @override
  String get txTypeTripPayment => 'Trip payment';

  @override
  String get txTypeTripDebit => 'Trip fee';

  @override
  String get txTypeRefund => 'Refund';

  @override
  String get txTypePayout => 'Payout';

  @override
  String get txTypeAdjustment => 'Balance adjustment';

  @override
  String get txTypeHold => 'Hold amount';

  @override
  String get txTypeReleaseHold => 'Release hold';

  @override
  String get transactionsLog => 'Transactions log';

  @override
  String get topUpShort => 'Top up';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get pendingChargesShortcutTitle => 'Pending charges';

  @override
  String get pendingChargesShortcutSubtitle =>
      'View pending fines and charges and top up your wallet';

  @override
  String get freeTripUsed => 'The free trip has been used';

  @override
  String get freeTripAvailableDriver =>
      'You have one free trip to unlock passenger details';

  @override
  String get vehicleSettingsTitle => 'Vehicle Settings';

  @override
  String get seatLayoutSavedSuccess => 'Vehicle seat layout saved';

  @override
  String get noVehicleRegistered => 'No vehicle registered yet';

  @override
  String get noVehicleRegisteredBody =>
      'You need to register your vehicle by completing the driver profile before customizing the seat layout.';

  @override
  String get vehicleDataSection => 'Vehicle data';

  @override
  String get vehicleModelLabel => 'Model';

  @override
  String get vehicleTypeLabel => 'Type';

  @override
  String get vehiclePlateNumberLabel => 'Plate number';

  @override
  String get registeredSeatsCount => 'Registered seats count';

  @override
  String get seatLayoutSection => 'Seat layout';

  @override
  String get seatLayoutUsedForAllTrips =>
      'This layout is used for all trips you create with this vehicle.';

  @override
  String get gridSystem => 'Grid system';

  @override
  String get customLayout => 'Custom layout';

  @override
  String get rowsLabel => 'Rows';

  @override
  String get perRowLabel => 'Per row';

  @override
  String get setSeatsPerRow => 'Set the number of seats in each row:';

  @override
  String get nextToDriver => 'Next to driver';

  @override
  String rowNumberLabel(int number) {
    return 'Row $number';
  }

  @override
  String get addNewRow => 'Add new row';

  @override
  String get preventGenderMixing => 'Prevent gender mixing';

  @override
  String get saveChangesVehicle => 'Save changes';

  @override
  String get editingForActiveTripsOnly =>
      'Editing is available for active trips only';

  @override
  String get bookedSeatsManagedByBookings =>
      'Seats booked through the app are managed from booking requests';

  @override
  String get openSeatTitle => 'Open seat';

  @override
  String openSeatBody(int number) {
    return 'Unlock seat number $number so it becomes available for booking in the app?';
  }

  @override
  String get openSeat => 'Open seat';

  @override
  String get seatOpenedSuccess => 'Seat opened';

  @override
  String get lockSeatTitle => 'Lock seat';

  @override
  String lockSeatBody(int number) {
    return 'Lock seat number $number? Passengers won\'t be able to book it in the app (e.g. if sold outside the app).';
  }

  @override
  String get lockSeat => 'Lock';

  @override
  String get seatLockedSuccess => 'Seat locked';

  @override
  String get enableLocationRequired => 'Location enable required';

  @override
  String get enableLocationBody =>
      'The trip cannot continue without location services enabled. Please enable GPS now.';

  @override
  String get openLocationSettings => 'Open location settings';

  @override
  String get checkAgain => 'Check again';

  @override
  String get tripManagementTitle => 'Trip Management';

  @override
  String get freeTripDiscountLabel => 'Free trip discount';

  @override
  String freeTripDiscountValue(String amount, String currency) {
    return '-$amount $currency (100%)';
  }

  @override
  String get freeTripAvailableExplanation =>
      'You have a free trip available. A 100% discount will be applied to make the total 0.';

  @override
  String get tripFeeFullExplanation =>
      'The payment covers the full trip fee and does not change the number of seats or bookings.';

  @override
  String get hideTripTitle => 'Hide Trip';

  @override
  String get hideTripConfirm => 'Are you sure you want to hide this trip?';

  @override
  String get hideAction => 'Hide';

  @override
  String get tripHiddenSuccess => 'Trip hidden successfully';

  @override
  String get tripShownSuccess => 'Trip shown successfully';

  @override
  String get deleteTripTitle => 'Delete Trip';

  @override
  String get deleteTripConfirm =>
      'Are you sure you want to delete this trip? This action cannot be undone.';

  @override
  String get deleteAction => 'Delete';

  @override
  String get tripDeletedSuccess => 'Trip deleted successfully';

  @override
  String get hideTripTooltip => 'Hide trip';

  @override
  String get showTripTooltip => 'Show trip';

  @override
  String get deleteTripTooltip => 'Delete trip';

  @override
  String walletBalanceWithAmount(String amount, String currency) {
    return 'Wallet balance: $amount $currency';
  }

  @override
  String get freeTripAvailableShort => 'Free trip available';

  @override
  String get balanceFromPlatformWallet =>
      'Balance from the platform wallet (unified wallet)';

  @override
  String get tripFeeLabel => 'Trip fee';

  @override
  String get tripFeeReady => 'Trip fee invoice is ready';

  @override
  String tripFeeBreakdownWithFreeTrip(
    int seats,
    String price,
    String currency,
    String amount,
  ) {
    return 'Fee: 5% × $seats seats × $price $currency, free trip discount 100% = $amount $currency';
  }

  @override
  String tripFeeBreakdown(
    int seats,
    String price,
    String currency,
    String amount,
  ) {
    return '5% × $seats seats × $price $currency = $amount $currency';
  }

  @override
  String get applyFreeTrip => 'Apply free trip';

  @override
  String pendingBookingsCard(int count) {
    return 'Pending bookings ($count)';
  }

  @override
  String get confirmBookingUnlocksDetails =>
      'Confirming the booking unlocks passenger details (free trip or one-time wallet deduction per trip)';

  @override
  String get passengerFallback => 'Passenger';

  @override
  String seatLabelShort(String seat) {
    return 'Seat $seat';
  }

  @override
  String get chatAvailableAfterFee =>
      'Chat and contact are available after paying the trip fee';

  @override
  String get awaitingConfirmation => 'Awaiting confirmation';

  @override
  String seatsWithValue(String seat) {
    return 'Seats: $seat';
  }

  @override
  String get pendingConfirmationBadge => 'Pending confirmation';

  @override
  String get passengerDetailsButton => 'Passenger details';

  @override
  String get confirmingInProgress => 'Confirming...';

  @override
  String get rejectingInProgress => 'Rejecting...';

  @override
  String get rejectAction => 'Reject';

  @override
  String get bookingRejected => 'Booking rejected';

  @override
  String get bookedSeatsLabel => 'Booked seats';

  @override
  String ofCount(int count) {
    return 'of $count';
  }

  @override
  String get revenueLabel => 'Revenue';

  @override
  String get confirmArrivalTitle => 'Confirm arrival';

  @override
  String get confirmArrivalBody =>
      'Have you arrived at the destination? The trip will be ended and cannot be undone.';

  @override
  String get yesArrived => 'Yes, I arrived';

  @override
  String get tripEndedSuccess => 'Trip ended successfully.';

  @override
  String autoStartHours(int hours) {
    return 'The trip will start automatically at the departure time (in ~$hours hours). No need to press a start button.';
  }

  @override
  String autoStartMinutes(int minutes) {
    return 'The trip will start automatically at the departure time (in ~$minutes minutes). No need to press a start button.';
  }

  @override
  String get tripWillConvertSoon =>
      'The trip will be converted to \"In progress\" automatically in a moment.';

  @override
  String get startTripSection => 'Start trip';

  @override
  String get endTripSection => 'End trip';

  @override
  String get endTripHint =>
      'Press \"Arrived at destination\" after dropping off passengers to end the trip.';

  @override
  String get endingInProgress => 'Ending...';

  @override
  String get arrivedAtDestination => 'Arrived at destination';

  @override
  String get tripStatusLabel => 'Trip status';

  @override
  String get departureTimeDetailLabel => 'Departure time';

  @override
  String get pricePerSeatLabel => 'Price per seat';

  @override
  String get seatsDetailLabel => 'Seats';

  @override
  String seatsAvailableTotal(int available, int total) {
    return '$available available / $total total';
  }

  @override
  String get seatLayoutDetailLabel => 'Seat layout';

  @override
  String get yesLabel => 'Yes';

  @override
  String get noLabel => 'No';

  @override
  String get seatLayoutCardTitle => 'Seat layout';

  @override
  String get seatLayoutLongPressHint =>
      'Long-press a green seat to lock it (external booking), or a locked seat to open it.';

  @override
  String get driverSeat => 'Driver seat';

  @override
  String get legendAvailable => 'Available';

  @override
  String get legendLocked => 'Locked';

  @override
  String get legendBookedMale => 'Booked - male';

  @override
  String get legendBookedFemale => 'Booked - female';

  @override
  String passengersCardTitle(int count) {
    return 'Passengers ($count)';
  }

  @override
  String get anonymousPassenger => 'Anonymous passenger';

  @override
  String get confirmedBadge => 'Confirmed';

  @override
  String get imageLoadFailed => 'Failed to load image';

  @override
  String get quickActionsTitle => 'Quick actions';

  @override
  String get shareAction => 'Share';

  @override
  String get shareFeatureComingSoon => 'Coming soon: share feature';

  @override
  String get editAction => 'Edit';

  @override
  String get carImage => 'Car Image';

  @override
  String passengersWithCount(int count) {
    return 'Passengers ($count)';
  }

  @override
  String get passengerLabel => 'Passenger';

  @override
  String seatNumberLabel(Object number) {
    return 'Seat $number';
  }

  @override
  String get confirmedLabel => 'Confirmed';

  @override
  String pendingBookingsWithCount(int count) {
    return 'Bookings Pending Confirmation ($count)';
  }

  @override
  String get pendingBookingHint =>
      'Confirming the booking unlocks the passenger\'s details (a free trip or a one-time wallet deduction for the trip)';

  @override
  String get pendingConfirmation => 'Pending confirmation';

  @override
  String get confirmingBooking => 'Confirming...';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get bookedSeats => 'Booked Seats';

  @override
  String ofTotalSeats(Object total) {
    return 'of $total';
  }

  @override
  String get revenue => 'Revenue';

  @override
  String get tripDetails => 'Trip Details';

  @override
  String get tripDistance => 'Trip Distance';

  @override
  String distanceInKm(String distance) {
    return '$distance km';
  }

  @override
  String get seatsLabel => 'Seats';

  @override
  String availableOfTotalSeats(Object available, Object total) {
    return '$available available / $total total';
  }

  @override
  String get seatLayout => 'Seat Layout';

  @override
  String get tripInfo => 'Trip Information';

  @override
  String get tripStatusCompleted => 'Completed';

  @override
  String get tripStatusUnknown => 'Unknown';

  @override
  String get tripStatusTitle => 'Trip Status';

  @override
  String get freeTripAvailable => 'Free trip available';

  @override
  String markAllNotificationsRead(int count) {
    return 'Mark all notifications as read ($count unread)';
  }

  @override
  String get allNotificationsRead => 'All notifications marked as read';

  @override
  String markAllReadCount(int count) {
    return 'Mark all read ($count)';
  }

  @override
  String get notificationsWillAppearHere =>
      'Notifications will appear here when they arrive';

  @override
  String get manualPaymentTitle => 'Manual Payment';

  @override
  String get completePayment => 'Complete Payment';

  @override
  String get walletType => 'Wallet Type';

  @override
  String get walletTypeOther => 'Other';

  @override
  String get jordan => 'Jordan';

  @override
  String get walletNumber => 'Wallet Number';

  @override
  String get walletNumberHint => 'e.g. 0791234567';

  @override
  String get walletNumberRequired => 'Please enter the wallet number';

  @override
  String get walletNumberTooShort => 'Wallet number must be at least 8 digits';

  @override
  String get paymentProofImage => 'Payment Proof Image';

  @override
  String get requiredLabel => '(Required)';

  @override
  String get requiredWord => 'Required';

  @override
  String get uploadPaymentProof => 'Upload payment proof image';

  @override
  String get tapToUploadPaymentProof => 'Tap to upload payment proof image';

  @override
  String get notesLabel => 'Notes';

  @override
  String get additionalNotes => 'Additional Notes';

  @override
  String get additionalNotesHint => 'Any additional information...';

  @override
  String get submitPaymentRequest => 'Submit Payment Request';

  @override
  String get paymentTabAll => 'All';

  @override
  String get paymentStatusPending => 'Pending';

  @override
  String get paymentStatusApproved => 'Approved';

  @override
  String get paymentStatusRejected => 'Rejected';

  @override
  String get paymentStatusRefunded => 'Refunded';

  @override
  String get errorLoadingData => 'An error occurred while loading data';

  @override
  String get noPayments => 'No payments';

  @override
  String get paymentMethodWallet => 'App Wallet';

  @override
  String get paymentMethodManual => 'E-Wallet';

  @override
  String get paymentMethodCommunicationFee => 'Communication Fee';

  @override
  String get amountLabel => 'Amount';

  @override
  String get purposeLabel => 'Purpose';

  @override
  String get communicationUnlockFee => 'Communication unlock fee';

  @override
  String get paymentMethodLabel => 'Payment Method';

  @override
  String get profileUpdatedSuccess => 'Profile updated successfully';

  @override
  String get gallery => 'Gallery';

  @override
  String get camera => 'Camera';

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get chooseProfilePhoto => 'Choose profile photo';

  @override
  String get changeProfilePhoto => 'Change profile photo';

  @override
  String get hidePhoneFromDriver => 'Hide phone number from driver';

  @override
  String get loadingVersion => 'Loading version...';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get aboutAppTagline =>
      'A smart mobility platform connecting drivers and passengers with a clear, fast, and reliable Arabic experience.';

  @override
  String get whatMakesVisionWaySpecial => 'What makes VisionWay special?';

  @override
  String get aboutFeatureArabicFirst =>
      'Arabic-first interface with a clear and fast user experience.';

  @override
  String get aboutFeatureFlexibleManagement =>
      'Flexible management of trips, bookings, and driver-passenger communication.';

  @override
  String get aboutFeatureTrustDesign =>
      'A design focused on trust, simplicity, and easy access to important information.';

  @override
  String get revokeDeviceTitle => 'Revoke Device';

  @override
  String get revokeDeviceMessage =>
      'Are you sure you want to revoke this device? You will need to sign in again on this device.';

  @override
  String get deviceRevokedSuccess => 'Device revoked successfully';

  @override
  String get retry => 'Retry';

  @override
  String get noDevicesRegistered => 'No devices registered';

  @override
  String deviceLastSeen(String date) {
    return 'Last seen: $date';
  }

  @override
  String get deviceCurrentBadge => 'Current';

  @override
  String get roleDriver => 'Driver';

  @override
  String get rolePassenger => 'Passenger';

  @override
  String get manageDevices => 'Manage Devices';

  @override
  String get manageDevicesSubtitle =>
      'View and revoke devices linked to your account';

  @override
  String get enterNewPassword => 'Please enter new password';

  @override
  String get passwordChangedTitle => 'Password Changed';

  @override
  String get passwordChangedMessage =>
      'Your password has been changed successfully. Please sign in again.';

  @override
  String get changePasswordSubtitle =>
      'Enter your current password and new password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get passwordStrengthMedium => 'Medium';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordPolicyHint =>
      'Must be at least 8 characters with one letter and one number';

  @override
  String get deleteAccountSecondTitle => 'Confirm Deletion';

  @override
  String get driverSection => 'Driver';

  @override
  String get vehicleAndSeatLayout => 'Vehicle & Seat Layout';

  @override
  String get supportNumberUnavailable =>
      'The support number is currently unavailable';

  @override
  String get supportWhatsAppPrefill =>
      'Hello, I need help with the VisionWay app.';

  @override
  String get cannotOpenWhatsApp => 'Could not open WhatsApp';

  @override
  String get cannotOpenEmailApp => 'Could not open the email app';

  @override
  String get supportEmailCopied => 'Support email copied';

  @override
  String get supportHeroTitle => 'We\'re here to help';

  @override
  String get supportHeroSubtitle =>
      'If you face an issue with booking, your account, or payments, you can contact the VisionWay team directly.';

  @override
  String get supportContactEmailTitle => 'Email us';

  @override
  String get supportContactEmailDescription =>
      'Send your inquiry and we\'ll review your message as soon as possible.';

  @override
  String get supportSendEmail => 'Send Email';

  @override
  String get supportCopyEmail => 'Copy Email';

  @override
  String get supportContactWhatsAppTitle => 'Message us on WhatsApp';

  @override
  String get supportContactWhatsAppDescription =>
      'Contact the support team directly via WhatsApp for instant help.';

  @override
  String get supportHowWeHelpTitle => 'How can we help?';

  @override
  String get supportHelpItemLogin =>
      'Issues with signing in or updating account details';

  @override
  String get supportHelpItemBookings =>
      'Inquiries about bookings, trips, and payments';

  @override
  String get supportHelpItemTechnical =>
      'Reviewing technical issues or suggestions';

  @override
  String get supportQuickTipTitle => 'Quick tip';

  @override
  String get supportTipIncludeContact =>
      'Include the phone number or email registered in the app to speed up the review.';

  @override
  String get supportTipDescribeProblem =>
      'Add a brief description of the problem and the steps that preceded it.';

  @override
  String get enterValidAmount => 'Enter a valid amount';

  @override
  String get uploadTransferProofRequired =>
      'Please upload the transfer proof image';

  @override
  String get enterCliqAliasValue => 'Enter the CliQ alias value';

  @override
  String get topupRequestSent =>
      'Top-up request sent. The balance will be added after the transfer is verified';

  @override
  String get verifyingPaymentStatus => 'Verifying payment status...';

  @override
  String verifyingPaymentStatusProgress(int attempt, int total) {
    return 'Verifying payment status... ($attempt/$total)';
  }

  @override
  String get walletToppedUpViaCliq => 'Wallet topped up successfully via CliQ';

  @override
  String get cliqPaymentFailed => 'CliQ payment failed';

  @override
  String cliqPaymentFailedWithNote(String note) {
    return 'Payment failed: $note';
  }

  @override
  String connectionTemporarilyFailed(int attempt, int total) {
    return 'Connection temporarily failed ($attempt/$total). Retrying...';
  }

  @override
  String cannotVerifyPayment(String detail) {
    return 'Could not verify payment: $detail';
  }

  @override
  String get verificationTimedOut =>
      'Verification timed out. If the payment completed in CliQ, the balance will appear within minutes, or check your payment history.';

  @override
  String get walletTopupTitle => 'Top Up Wallet';

  @override
  String get pleaseWaitDoNotClose => 'Please wait and do not close the screen';

  @override
  String get topupMethodManual => 'Manual Transfer';

  @override
  String get topupManualDescription =>
      'Transfer the amount to the platform account, then enter the amount and upload a clear image of the transfer. No balance is added automatically before the request is reviewed.';

  @override
  String get topupCliqDescription =>
      'Payment will be made directly via CliQ. Enter the amount and your CliQ account details, and the balance will be added automatically once the payment is confirmed.';

  @override
  String amountWithCurrency(String currency) {
    return 'Amount ($currency)';
  }

  @override
  String get transactionReferenceOptional =>
      'Transaction number / reference (optional)';

  @override
  String get ifAvailable => 'If available';

  @override
  String get uploadTransferProof => 'Upload transfer proof image';

  @override
  String get imageSelected => 'Image selected';

  @override
  String get aliasType => 'Alias Type';

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get aliasName => 'Alias';

  @override
  String get aliasNameLabel => 'Alias';

  @override
  String get mobileNumberHint => 'e.g. 00962XXXXXXXXX';

  @override
  String get aliasNameHint => 'e.g. yourname@cliq';

  @override
  String get enterMobileNumber => 'Enter the mobile number';

  @override
  String get enterAliasName => 'Enter the alias';

  @override
  String get submitTopupRequest => 'Submit Top-Up Request';

  @override
  String get payViaCliq => 'Pay via CliQ';

  @override
  String get chatYourMessage => 'Your message';

  @override
  String chatMessageFrom(String name) {
    return 'Message from $name';
  }

  @override
  String chatYesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String chatDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String countryCodePickerSemantic(String country) {
    return 'Select country code, current: $country';
  }

  @override
  String get selectCountry => 'Select country';

  @override
  String get searchCountryHint => 'Search by name or country code...';

  @override
  String get locationDefaultAmman => 'Amman, Jordan';

  @override
  String get locationCurrentUnavailable =>
      'Could not get the current location.';

  @override
  String get locationServicesDisabledEnableGps =>
      'Location services are disabled. Please enable GPS.';

  @override
  String get locationEnable => 'Enable';

  @override
  String get locationGrantPermission => 'Grant permission';

  @override
  String get locationSettings => 'Settings';

  @override
  String get locationUnknown => 'Unknown location';

  @override
  String get locationGetError => 'Error getting the location.';

  @override
  String get locationGrant => 'Grant';

  @override
  String get locationPermissionDeniedPermanently =>
      'Permission permanently denied.';

  @override
  String get locationSearchNoResults =>
      'No results found. Try a clearer place name or address.';

  @override
  String locationSearchError(String error) {
    return 'Search error: $error';
  }

  @override
  String get locationUseCurrent => 'Use current location';

  @override
  String get locationSearchSemantic => 'Search for a place or address';

  @override
  String get locationSearchHint => 'Search for a place or address...';

  @override
  String get locationSearchOnMap => 'Search on map';

  @override
  String get locationLoadingMap => 'Loading map...';

  @override
  String get locationMapLoadError => 'Error loading the map';

  @override
  String get locationPickOnMap => 'Pick a location on the map';

  @override
  String get locationConfirm => 'Confirm location';

  @override
  String get notificationDeleted => 'Notification deleted';

  @override
  String notificationsWithUnread(int count) {
    return 'Notifications ($count unread)';
  }

  @override
  String ratingStars(int count) {
    return '$count stars';
  }

  @override
  String ratingStarsSelected(int count) {
    return '$count stars (selected)';
  }

  @override
  String get seatDriverSeat => 'Driver seat';

  @override
  String get seatStatusAvailable => 'Available';

  @override
  String get seatStatusBooked => 'Booked';

  @override
  String get seatStatusLocked => 'Locked';

  @override
  String get seatStatusUnavailable => 'Unavailable';

  @override
  String get seatStatusInvalid => 'Invalid';

  @override
  String seatLabelSelected(int number, String status) {
    return 'Seat $number $status, selected';
  }

  @override
  String get seatLegendSelected => 'Selected';

  @override
  String get seatLegendLockedExternal => 'Locked (outside the app)';

  @override
  String seatColorGuide(String label) {
    return 'Color guide: $label';
  }

  @override
  String walletBalanceWithValue(String balance, String currency) {
    return 'Wallet balance: $balance $currency';
  }

  @override
  String seatLabelNumbered(int number, String status) {
    return 'Seat $number $status';
  }

  @override
  String get accountBannedNoReason =>
      'Your account has been suspended. Contact support for details.';

  @override
  String get bannedWhatsAppPrefill =>
      'Hello, my VisionWay account is suspended and I need help.';

  @override
  String get followUs => 'Follow us';

  @override
  String get followOnFacebook => 'Facebook';

  @override
  String get followOnLinkedIn => 'LinkedIn';

  @override
  String get tripGroupChat => 'Trip group chat';

  @override
  String groupChatMembersCount(int count) {
    return '$count members';
  }

  @override
  String get shareTripTrackingTitle => 'Share trip tracking';

  @override
  String get shareTripTrackingMessage =>
      'Share your live trip tracking with someone?';

  @override
  String get shareTripTrackingAction => 'Share';

  @override
  String get shareTripTrackingLater => 'Later';

  @override
  String shareTripTrackingText(String url) {
    return 'Follow my live trip here: $url';
  }

  @override
  String get shareTripTrackingError => 'Could not create the share link';

  @override
  String get locationAutocompleteSuggestions => 'Place suggestions';

  @override
  String get locationAutocompleteNoResults =>
      'No matching places. Pick the location on the map instead.';

  @override
  String get instantRidesTitle => 'Instant rides';

  @override
  String get instantOnlineReady => 'Online — ready for requests';

  @override
  String get instantOffline => 'Offline';

  @override
  String get instantOfferTitle => 'Instant ride request';

  @override
  String get instantRideAcceptedToast =>
      'Ride accepted. Head to the pickup point.';

  @override
  String instantOfferCountdown(int seconds) {
    return 'Expires in ${seconds}s';
  }

  @override
  String get instantDecline => 'Decline';

  @override
  String get instantAccept => 'Accept';

  @override
  String get instantRequestNow => 'Request now';

  @override
  String get instantRequestNowTitle => 'Request a ride now';

  @override
  String get instantRequestNowSubtitle =>
      'A nearby driver comes straight to you';

  @override
  String get instantSelectFromTo => 'Choose pickup and destination.';

  @override
  String get instantFromHint => 'Pickup location';

  @override
  String get instantFromPickerTitle => 'Choose pickup point';

  @override
  String get instantToHint => 'Destination';

  @override
  String get instantToPickerTitle => 'Choose destination';

  @override
  String get instantDriverFound => 'Driver found!';

  @override
  String get instantDriverOnTheWay =>
      'The driver is on the way to the pickup point.';

  @override
  String get instantTrackTrip => 'Track ride';

  @override
  String get instantDone => 'Done';

  @override
  String get instantRequestCancelled => 'Request cancelled';

  @override
  String get instantNoDrivers => 'No driver available';

  @override
  String get instantNoDriversSubtitle =>
      'We couldn\'t find a nearby driver right now. Please try again.';

  @override
  String get instantTryAgain => 'Try again';

  @override
  String get instantSearching => 'Finding the nearest driver...';

  @override
  String instantFareEstimate(String fare, String currency) {
    return 'Estimated fare: $fare $currency';
  }

  @override
  String get instantCancelRequest => 'Cancel request';

  @override
  String get instantYourFareLabel => 'Your fare';

  @override
  String instantRecommendedFare(String fare, String currency) {
    return 'Recommended fare: $fare $currency';
  }

  @override
  String instantYourFareValue(String fare, String currency) {
    return 'Your fare: $fare $currency';
  }

  @override
  String get instantDriverOfferTitle => 'Driver\'s offer';

  @override
  String get instantProposeFare => 'Offer a higher fare';

  @override
  String get instantSendOffer => 'Send offer';

  @override
  String get instantCounterSentToast =>
      'Your offer was sent to the passenger. Waiting for approval...';

  @override
  String instantCounterMaxHint(String fare, String currency) {
    return 'Max: $fare $currency';
  }
}
