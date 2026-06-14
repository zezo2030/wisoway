import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/services/payment_service.dart';
import '../../models/payment_model.dart';
import '../../l10n/l10n_extensions.dart';

enum _TopupMethod { manual, cliqA2a }

class WalletTopupRequestScreen extends StatefulWidget {
  const WalletTopupRequestScreen({super.key});

  @override
  State<WalletTopupRequestScreen> createState() =>
      _WalletTopupRequestScreenState();
}

class _WalletTopupRequestScreenState extends State<WalletTopupRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _walletRefController = TextEditingController();
  final _aliasValueController = TextEditingController();
  final PaymentService _paymentService = PaymentService();

  _TopupMethod _selectedMethod = _TopupMethod.manual;
  String _aliasType = 'MOBL';

  File? _proofImage;
  bool _isLoading = false;
  bool _isPolling = false;
  String? _pollingStatus;

  @override
  void dispose() {
    _amountController.dispose();
    _walletRefController.dispose();
    _aliasValueController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null && mounted) {
      setState(() => _proofImage = File(x.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0.01) {
      _showSnack(context.l10n.enterValidAmount, isError: true);
      return;
    }

    if (_selectedMethod == _TopupMethod.manual && _proofImage == null) {
      _showSnack(context.l10n.uploadTransferProofRequired, isWarning: true);
      return;
    }

    if (_selectedMethod == _TopupMethod.cliqA2a &&
        _aliasValueController.text.trim().isEmpty) {
      _showSnack(context.l10n.enterCliqAliasValue, isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_selectedMethod == _TopupMethod.manual) {
        await _paymentService.createWalletTopup(
          amount: amount,
          currency: 'JOD',
          method: 'manual',
          proofImage: _proofImage,
          walletNumber: _walletRefController.text.trim().isEmpty
              ? null
              : _walletRefController.text.trim(),
        );
        if (!mounted) return;
        _showSnack(
          context.l10n.topupRequestSent,
          isSuccess: true,
        );
        Navigator.pop(context, true);
      } else {
        await _submitCliq(amount);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack(context.l10n.errorWithDetail(e.toString()), isError: true);
      }
    }
  }

  Future<void> _submitCliq(double amount) async {
    final payment = await _paymentService.createWalletTopup(
      amount: amount,
      currency: 'JOD',
      method: 'cliq_a2a',
      aliasType: _aliasType,
      aliasValue: _aliasValueController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isPolling = true;
      _pollingStatus = context.l10n.verifyingPaymentStatus;
    });

    await _pollStatus(payment.id);
  }

  Future<void> _pollStatus(String paymentId) async {
    const maxAttempts = 24;
    const interval = Duration(seconds: 5);
    var consecutiveErrors = 0;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        await Future.delayed(interval);
      }
      if (!mounted) return;

      setState(() {
        _pollingStatus =
            context.l10n.verifyingPaymentStatusProgress(attempt, maxAttempts);
      });

      try {
        final updated =
            await _paymentService.refreshCliqPaymentStatus(paymentId);
        consecutiveErrors = 0;
        if (!mounted) return;

        if (updated.status == PaymentStatus.approved) {
          setState(() => _isPolling = false);
          _showSnack(context.l10n.walletToppedUpViaCliq, isSuccess: true);
          Navigator.pop(context, true);
          return;
        } else if (updated.status == PaymentStatus.rejected) {
          setState(() {
            _isPolling = false;
            _pollingStatus = null;
          });
          final note = (updated.adminNote ?? '').trim();
          _showSnack(
            note.isEmpty
                ? context.l10n.cliqPaymentFailed
                : context.l10n.cliqPaymentFailedWithNote(note),
            isError: true,
          );
          Navigator.pop(context, false);
          return;
        }
      } catch (e) {
        consecutiveErrors++;
        if (!mounted) return;
        setState(() {
          _pollingStatus = context.l10n.connectionTemporarilyFailed(
            attempt,
            maxAttempts,
          );
        });
        if (consecutiveErrors >= 5) {
          setState(() => _isPolling = false);
          _showSnack(
            context.l10n.cannotVerifyPayment(e.toString()),
            isError: true,
          );
          Navigator.pop(context, false);
          return;
        }
      }
    }

    if (mounted) {
      setState(() => _isPolling = false);
      _showSnack(
        context.l10n.verificationTimedOut,
        isWarning: true,
      );
      Navigator.pop(context, false);
    }
  }

  void _showSnack(
    String message, {
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
  }) {
    if (!mounted) return;
    Color bg;
    if (isError) {
      bg = T.error(context);
    } else if (isSuccess) {
      bg = AppColors.success;
    } else {
      bg = AppColors.warning;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        title: Text(
          context.l10n.walletTopupTitle,
          style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
        ),
      ),
      body: _isPolling ? _buildPollingView() : _buildForm(),
    );
  }

  Widget _buildPollingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _pollingStatus ?? context.l10n.verifyingPaymentStatus,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.pleaseWaitDoNotClose,
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onSurfaceVariant(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMethodSelector(),
            const SizedBox(height: 20),
            _buildDescription(),
            const SizedBox(height: 24),
            _buildAmountField(),
            const SizedBox(height: 16),
            if (_selectedMethod == _TopupMethod.manual) ...[
              _buildReferenceField(),
              const SizedBox(height: 20),
              _buildProofImagePicker(),
            ] else ...[
              _buildAliasTypeSelector(),
              const SizedBox(height: 16),
              _buildAliasValueField(),
            ],
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildMethodTab(
            label: context.l10n.topupMethodManual,
            icon: IconsaxPlusLinear.gallery_add,
            value: _TopupMethod.manual,
          ),
          _buildMethodTab(
            label: 'CliQ A2A',
            icon: IconsaxPlusLinear.flash,
            value: _TopupMethod.cliqA2a,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab({
    required String label,
    required IconData icon,
    required _TopupMethod value,
  }) {
    final selected = _selectedMethod == value;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: selected,
        child: GestureDetector(
          onTap: () => setState(() => _selectedMethod = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.teal700 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.white : T.onSurfaceVariant(context),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color:
                        selected ? AppColors.white : T.onSurfaceVariant(context),
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDescription() {
    final text = _selectedMethod == _TopupMethod.manual
        ? context.l10n.topupManualDescription
        : context.l10n.topupCliqDescription;
    return Text(
      text,
      style: AppTextStyles.bodyMedium.copyWith(
        color: T.onSurfaceVariant(context),
      ),
    );
  }

  Widget _buildAmountField() {
    final currency = 'JOD';
    return TextFormField(
      controller: _amountController,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: context.l10n.amountWithCurrency(currency),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(IconsaxPlusLinear.dollar_circle),
      ),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        if (n == null || n < 0.01) return context.l10n.enterValidAmount;
        return null;
      },
    );
  }

  Widget _buildReferenceField() {
    return TextFormField(
      controller: _walletRefController,
      decoration: InputDecoration(
        labelText: context.l10n.transactionReferenceOptional,
        hintText: context.l10n.ifAvailable,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: const Icon(IconsaxPlusLinear.document_text),
      ),
    );
  }

  Widget _buildProofImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: _proofImage == null
              ? context.l10n.uploadTransferProof
              : context.l10n.imageSelected,
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: Icon(
              _proofImage == null
                  ? IconsaxPlusLinear.gallery_add
                  : IconsaxPlusBold.tick_circle,
            ),
            label: Text(
              _proofImage == null
                  ? context.l10n.uploadTransferProof
                  : context.l10n.imageSelected,
              style: AppTextStyles.labelLarge,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_proofImage != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _proofImage!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAliasTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.aliasType,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAliasTypeOption(
              label: context.l10n.mobileNumber,
              subtitle: 'MOBL',
              value: 'MOBL',
              icon: IconsaxPlusLinear.mobile,
            ),
            const SizedBox(width: 12),
            _buildAliasTypeOption(
              label: context.l10n.aliasName,
              subtitle: 'ALIAS',
              value: 'ALIAS',
              icon: IconsaxPlusLinear.user_tag,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAliasTypeOption({
    required String label,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final selected = _aliasType == value;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: selected,
        child: InkWell(
          onTap: () => setState(() => _aliasType = value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.teal700.withValues(alpha: 0.1)
                  : T.surfaceVariant(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.teal700 : AppColors.slate300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    color: selected
                        ? AppColors.teal700
                        : T.onSurfaceVariant(context)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: selected ? AppColors.teal700 : T.onSurface(context),
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAliasValueField() {
    final hint = _aliasType == 'MOBL'
        ? context.l10n.mobileNumberHint
        : context.l10n.aliasNameHint;
    return TextFormField(
      controller: _aliasValueController,
      decoration: InputDecoration(
        labelText: _aliasType == 'MOBL'
            ? context.l10n.mobileNumber
            : context.l10n.aliasNameLabel,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(
          _aliasType == 'MOBL'
              ? IconsaxPlusLinear.mobile
              : IconsaxPlusLinear.user_tag,
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return _aliasType == 'MOBL'
              ? context.l10n.enterMobileNumber
              : context.l10n.enterAliasName;
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return Semantics(
      label: context.l10n.submitTopupRequest,
      button: true,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal700,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : Text(
                _selectedMethod == _TopupMethod.manual
                    ? context.l10n.submitTopupRequest
                    : context.l10n.payViaCliq,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
