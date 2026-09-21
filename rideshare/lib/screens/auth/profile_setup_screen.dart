import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/auth_step_indicator.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/security_notice.dart';

/// Passenger registration — step 3 of 3.
///
/// The account already exists at this point (created by the OTP step), so this
/// screen only collects the profile photo and the rider's city, then lands on
/// home.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final StorageService _storageService = StorageService();

  File? _profileImage;
  bool _isSaving = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(IconsaxPlusLinear.gallery),
              title: Text(context.l10n.fromGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.camera),
              title: Text(context.l10n.fromCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _storageService.pickImage(source: source);
    if (picked != null && mounted) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await context.read<AuthProvider>().completePassengerProfile(
        profileImage: _profileImage,
        city: _cityController.text.trim(),
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.home,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) ErrorSurface.showFailure(context, ApiClient.mapError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final totalSteps = (args?['authTotalSteps'] as int?) ?? 3;

    return Scaffold(
      backgroundColor: T.surface(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AuthStepIndicator(
                          currentStep: totalSteps,
                          totalSteps: totalSteps,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.authStepOf(totalSteps, totalSteps),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: T.primary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.passengerProfileStepTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: T.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.passengerProfileStepSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(child: _buildPhotoPicker()),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      l10n.profilePhotoRequired,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
                  const SizedBox(height: 26),
                  AuthTextField(
                    controller: _cityController,
                    label: l10n.profileCityLabel,
                    hint: l10n.profileCityHint,
                    icon: IconsaxPlusLinear.location,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.profileCityRequired
                        : null,
                  ),
                  const SizedBox(height: 20),
                  const Center(child: SecurityNotice()),
                  const SizedBox(height: 26),
                  AuthPrimaryButton(
                    label: l10n.complete,
                    loading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Semantics(
      button: true,
      label: context.l10n.uploadProfilePhoto,
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: T.surfaceVariant(context),
                border: Border.all(color: T.primary(context), width: 2),
                image: _profileImage != null
                    ? DecorationImage(
                        image: FileImage(_profileImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _profileImage == null
                  ? Icon(
                      IconsaxPlusBold.profile_circle,
                      size: 60,
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
