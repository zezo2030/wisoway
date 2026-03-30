import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../models/payment_model.dart';
import '../../../widgets/common/section_card.dart';

class ManualPaymentScreen extends StatefulWidget {
  final String paymentId;
  final String bookingId;

  const ManualPaymentScreen({
    super.key,
    required this.paymentId,
    required this.bookingId,
  });

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _walletNumberController = TextEditingController();
  final _notesController = TextEditingController();

  final PaymentService _paymentService = PaymentService();
  final StorageService _storageService = StorageService();

  String? _selectedWalletType;
  File? _proofImage;
  bool _isLoading = false;
  PaymentModel? _payment;

  final List<Map<String, String>> _walletTypes = [
    {'value': 'zain', 'label': 'Zain Cash', 'country': 'الأردن'},
    {'value': 'orange', 'label': 'Orange Money', 'country': 'الأردن'},
    {'value': 'cliq', 'label': 'Cliq', 'country': 'الأردن'},
    {'value': 'vodafone', 'label': 'Vodafone Cash', 'country': 'مصر'},
    {'value': 'etisalat', 'label': 'Etisalat Cash', 'country': 'مصر'},
    {'value': 'other', 'label': 'أخرى', 'country': ''},
  ];

  @override
  void initState() {
    super.initState();
    _loadPayment();
  }

  Future<void> _loadPayment() async {
    try {
      final payment = await _paymentService.getPayment(widget.paymentId);
      if (mounted) {
        setState(() {
          _payment = payment;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _payment = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل بيانات الدفع: ${e.toString()}'),
            backgroundColor: T.error(context),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _walletNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    final XFile? image = await _storageService.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      setState(() {
        _proofImage = File(image.path);
      });
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedWalletType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار نوع المحفظة'),
          backgroundColor: T.error(context),
        ),
      );
      return;
    }

    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى رفع صورة إثبات الدفع'),
          backgroundColor: T.error(context),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final proofImageUrl = await _paymentService.uploadProofImage(
        _proofImage!,
      );
      if (proofImageUrl.isEmpty) {
        throw Exception('فشل رفع صورة الإثبات');
      }

      await _paymentService.updateManualPayment(
        widget.paymentId,
        proofImageUrl: proofImageUrl,
        walletNumber: _walletNumberController.text.trim().isEmpty
            ? null
            : _walletNumberController.text.trim(),
        transactionId: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: T.error(context),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
          'الدفع اليدوي',
          style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.teal700, AppColors.teal500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal700.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          IconsaxPlusBold.wallet,
                          size: 48,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'إتمام الدفع',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (_payment != null)
                        Text(
                          '${_payment!.amount.toStringAsFixed(2)} ${_payment!.currency}',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SectionCard(
                  title: 'نوع المحفظة',
                  icon: IconsaxPlusBold.wallet,
                  iconColor: T.primary(context),
                  children: [
                    const SizedBox(height: 8),
                    ..._walletTypes.map(
                      (wallet) => _buildWalletTypeOption(
                        value: wallet['value']!,
                        label: wallet['label']!,
                        country: wallet['country']!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SectionCard(
                  title: 'رقم المحفظة',
                  icon: IconsaxPlusBold.call,
                  iconColor: T.primary(context),
                  children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _walletNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم المحفظة',
                        hintText: 'مثال: 0791234567',
                        prefixIcon: const Icon(IconsaxPlusLinear.call),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال رقم المحفظة';
                        }
                        if (value.length < 8) {
                          return 'رقم المحفظة يجب أن يكون 8 أرقام على الأقل';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SectionCard(
                  title: 'صورة إثبات الدفع',
                  icon: IconsaxPlusBold.image,
                  iconColor: T.primary(context),
                  subtitle: '(مطلوب)',
                  children: [
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: 'رفع صورة إثبات الدفع',
                      child: GestureDetector(
                        onTap: _pickProofImage,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: T.surface(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _proofImage != null
                                  ? AppColors.teal300
                                  : T.outlineVariant(context),
                              width: 2,
                            ),
                          ),
                          child: _proofImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        _proofImage!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: AppColors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.teal100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        IconsaxPlusBold.image,
                                        color: AppColors.teal700,
                                        size: 48,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'اضغط لرفع صورة إثبات الدفع',
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: T.onSurfaceVariant(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'مطلوب',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: T.onSurfaceVariant(context),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SectionCard(
                  title: 'ملاحظات',
                  icon: IconsaxPlusBold.note,
                  iconColor: AppColors.warning,
                  subtitle: '(اختياري)',
                  children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات إضافية',
                        hintText: 'أي معلومات إضافية...',
                        prefixIcon: const Icon(IconsaxPlusLinear.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Semantics(
                  label: 'إرسال طلب الدفع',
                  button: true,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal700.withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppColors.teal700,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'إرسال طلب الدفع',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletTypeOption({
    required String value,
    required String label,
    required String country,
  }) {
    final isSelected = _selectedWalletType == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: '$label - $country',
        selected: isSelected,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedWalletType = value;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.teal100 : T.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.teal300
                    : T.outlineVariant(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: T.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    IconsaxPlusBold.wallet,
                    color: AppColors.teal700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.teal800
                              : T.onSurface(context),
                        ),
                      ),
                      if (country.isNotEmpty)
                        Text(
                          country,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: T.onSurfaceVariant(context),
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: AppColors.teal700, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
