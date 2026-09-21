import 'package:flutter/material.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/auth/auth_primary_button.dart';
import '../../../widgets/auth/document_upload_box.dart';
import 'driver_profile_wizard_state.dart';

/// Driver wizard — step 3 of 3: registration form, insurance and car photo.
///
/// [onSubmit] performs the actual work: uploading the documents and either
/// creating the account (new registration) or PATCHing it (pending edit).
class DriverCompleteStep3 extends StatelessWidget {
  const DriverCompleteStep3({
    super.key,
    required this.state,
    required this.onPickVehicleLicense,
    required this.onPickInsurance,
    required this.onPickCarPhoto,
    required this.onBack,
    required this.onSubmit,
    required this.isSubmitting,
  });

  final DriverProfileWizardState state;
  final VoidCallback onPickVehicleLicense;
  final VoidCallback onPickInsurance;
  final VoidCallback onPickCarPhoto;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DocumentUploadBox(
          label: l10n.vehicleRegistrationFormRequired,
          file: state.vehicleLicenseImage,
          previewUrl: state.existingVehicleLicenseUrl,
          onTap: onPickVehicleLicense,
        ),
        const SizedBox(height: 18),
        DocumentUploadBox(
          label: l10n.insuranceDocumentLabel,
          file: state.insuranceImage,
          previewUrl: state.existingInsuranceUrl,
          onTap: onPickInsurance,
        ),
        const SizedBox(height: 18),
        DocumentUploadBox(
          label: l10n.carPhotoRequired,
          file: state.carImage,
          previewUrl: state.existingCarUrl,
          onTap: onPickCarPhoto,
        ),
        const SizedBox(height: 26),
        AuthPrimaryButton(
          label: state.isEditMode ? l10n.saveChangesButton : l10n.complete,
          loading: isSubmitting,
          onPressed: isSubmitting ? null : onSubmit,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: isSubmitting ? null : onBack,
          child: Text(l10n.back),
        ),
      ],
    );
  }
}
