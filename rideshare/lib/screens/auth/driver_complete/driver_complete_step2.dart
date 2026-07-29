import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/theme/colors.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/auth/auth_primary_button.dart';
import '../../../widgets/auth/auth_text_field.dart';
import '../../../widgets/auth/document_upload_box.dart';
import 'driver_profile_wizard_state.dart';

/// Driver wizard — step 2 of 3: photo, vehicle basics and the driving license.
///
/// Nothing is sent to the backend here; [onContinue] only advances to step 3
/// once this step's own fields validate.
class DriverCompleteStep2 extends StatelessWidget {
  const DriverCompleteStep2({
    super.key,
    required this.state,
    required this.formKey,
    required this.onPickProfilePhoto,
    required this.onPickLicense,
    required this.onSelectVehicleType,
    required this.onContinue,
  });

  final DriverProfileWizardState state;
  final GlobalKey<FormState> formKey;
  final VoidCallback onPickProfilePhoto;
  final VoidCallback onPickLicense;
  final VoidCallback onSelectVehicleType;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildPhotoPicker(context)),
          const SizedBox(height: 10),
          Center(
            child: Text(
              l10n.profilePhotoRequired,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: T.onSurface(context),
              ),
            ),
          ),
          Center(
            child: Text(
              l10n.profilePhotoClearHint,
              style: TextStyle(
                fontSize: 11,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            controller: state.vehicleTypeController,
            label: l10n.vehicleTypeRequired,
            helper: l10n.vehicleTypeSelectHint,
            icon: IconsaxPlusLinear.car,
            readOnly: true,
            onTap: onSelectVehicleType,
            suffix: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: T.onSurfaceVariant(context),
            ),
            validator: (_) => state.vehicleType == null
                ? l10n.vehicleTypeValidation
                : null,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: state.plateController,
            label: l10n.vehiclePlateRequiredLabel,
            helper: l10n.vehiclePlateDocHint,
            icon: IconsaxPlusLinear.card,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.vehiclePlateRequired
                : null,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: state.modelController,
            label: l10n.vehicleModelRequiredLabel,
            helper: l10n.vehicleModelDocHint,
            icon: IconsaxPlusLinear.car,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.vehicleModelRequired
                : null,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: state.seatsController,
            label: l10n.vehicleSeatsRequiredLabel,
            helper: l10n.vehicleSeatsDocHint,
            icon: IconsaxPlusLinear.people,
            keyboardType: TextInputType.number,
            // Seats always follow the vehicle-type template.
            readOnly: true,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return l10n.vehicleSeatsRequired;
              }
              final seats = int.tryParse(v.trim());
              if (seats == null || seats < 1) return l10n.vehicleSeatsInvalid;
              return null;
            },
          ),
          const SizedBox(height: 22),
          DocumentUploadBox(
            label: l10n.driverLicenseRequired,
            hint: l10n.driverLicenseUploadHint,
            file: state.licenseImage,
            previewUrl: state.existingLicenseUrl,
            onTap: onPickLicense,
          ),
          const SizedBox(height: 26),
          AuthPrimaryButton(label: l10n.continueLabel, onPressed: onContinue),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker(BuildContext context) {
    final file = state.profileImage;
    final url = state.existingPhotoUrl;

    return Semantics(
      button: true,
      label: context.l10n.uploadProfilePhoto,
      child: GestureDetector(
        onTap: onPickProfilePhoto,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: T.surfaceVariant(context),
                border: Border.all(color: T.primary(context), width: 2),
                image: file != null
                    ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                    : (url != null && url.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            )
                          : null),
              ),
              child: (file == null && (url == null || url.isEmpty))
                  ? Icon(
                      IconsaxPlusBold.profile_circle,
                      size: 58,
                      color: T.onSurfaceVariant(context),
                    )
                  : null,
            ),
            PositionedDirectional(
              bottom: 4,
              end: 4,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.primary(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: T.surface(context), width: 2),
                ),
                child: Icon(
                  IconsaxPlusBold.camera,
                  size: 16,
                  color: T.onPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
