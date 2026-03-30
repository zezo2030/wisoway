import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../core/services/payment_service.dart';

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
  final PaymentService _paymentService = PaymentService();
  File? _proofImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _walletRefController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('أدخل مبلغاً صحيحاً'),
          backgroundColor: T.error(context),
        ),
      );
      return;
    }
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى رفع صورة إثبات التحويل'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _paymentService.createWalletTopup(
        amount: amount,
        currency: 'EGP',
        method: 'manual',
        proofImage: _proofImage,
        walletNumber: _walletRefController.text.trim().isEmpty
            ? null
            : _walletRefController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'تم إرسال طلب الشحن. سيُضاف الرصيد بعد التحقق من التحويل',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: T.error(context)),
        );
      }
    }
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
          'شحن المحفظة',
          style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'حوّل المبلغ إلى حساب المنصة (حسب التعليمات الرسمية)، ثم أدخل المبلغ وارفع صورة واضحة لإثبات التحويل. لا يُضاف رصيد تلقائياً قبل مراجعة الطلب.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: T.onSurfaceVariant(context),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'المبلغ (EGP)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(IconsaxPlusLinear.dollar_circle),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0.01) return 'أدخل مبلغاً صحيحاً';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _walletRefController,
                decoration: InputDecoration(
                  labelText: 'رقم العملية / المرجع (اختياري)',
                  hintText: 'إن وُجد',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(IconsaxPlusLinear.document_text),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                label:
                    '${_proofImage == null ? 'رفع صورة إثبات التحويل' : 'تم اختيار صورة'}',
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(
                    _proofImage == null
                        ? IconsaxPlusLinear.gallery_add
                        : IconsaxPlusBold.tick_circle,
                  ),
                  label: Text(
                    _proofImage == null
                        ? 'رفع صورة إثبات التحويل'
                        : 'تم اختيار صورة',
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
              const SizedBox(height: 32),
              Semantics(
                label: 'إرسال طلب الشحن',
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
                          'إرسال طلب الشحن',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
