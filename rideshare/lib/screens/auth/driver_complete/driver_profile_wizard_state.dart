import 'dart:io';

import 'package:flutter/material.dart';

/// Shared state for driver wizard steps 2 and 3.
///
/// Holds the picked files and typed fields until the final submit, so moving
/// between the two steps never loses input. In edit mode the `existing*Url`
/// fields carry what the account already has, and a null [File] simply means
/// "left unchanged".
class DriverProfileWizardState extends ChangeNotifier {
  DriverProfileWizardState({this.isEditMode = false});

  /// 2 = vehicle + license, 3 = vehicle documents.
  int step = 2;

  /// True when reopened from the pending-review screen.
  final bool isEditMode;

  File? profileImage;
  File? licenseImage;
  File? vehicleLicenseImage;
  File? insuranceImage;
  File? carImage;

  String? existingPhotoUrl;
  String? existingLicenseUrl;
  String? existingVehicleLicenseUrl;
  String? existingInsuranceUrl;
  String? existingCarUrl;

  String? vehicleType;

  final plateController = TextEditingController();
  final modelController = TextEditingController();
  final seatsController = TextEditingController();

  /// Read-only mirror of the chosen [vehicleType]'s label, shown in the field.
  final vehicleTypeController = TextEditingController();

  bool get hasProfilePhoto =>
      profileImage != null || (existingPhotoUrl?.isNotEmpty ?? false);
  bool get hasLicense =>
      licenseImage != null || (existingLicenseUrl?.isNotEmpty ?? false);
  bool get hasVehicleLicense =>
      vehicleLicenseImage != null ||
      (existingVehicleLicenseUrl?.isNotEmpty ?? false);
  bool get hasInsurance =>
      insuranceImage != null || (existingInsuranceUrl?.isNotEmpty ?? false);
  bool get hasCarPhoto =>
      carImage != null || (existingCarUrl?.isNotEmpty ?? false);

  void goToStep(int value) {
    if (step == value) return;
    step = value;
    notifyListeners();
  }

  void setVehicleType(String? type, {String? label, int? seats}) {
    vehicleType = type;
    vehicleTypeController.text = label ?? type ?? '';
    if (seats != null) seatsController.text = '$seats';
    notifyListeners();
  }

  void setFile(void Function(DriverProfileWizardState state) update) {
    update(this);
    notifyListeners();
  }

  @override
  void dispose() {
    plateController.dispose();
    modelController.dispose();
    seatsController.dispose();
    vehicleTypeController.dispose();
    super.dispose();
  }
}
