import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../core/services/payment_service.dart';
import '../../models/payment_model.dart';
import '../../providers/auth_provider.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late TabController _tabController;
  PaymentStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _selectedStatus = null; // All
            break;
          case 1:
            _selectedStatus = PaymentStatus.pending;
            break;
          case 2:
            _selectedStatus = PaymentStatus.approved;
            break;
          case 3:
            _selectedStatus = PaymentStatus.rejected;
            break;
        }
      });
    });
    _selectedStatus = null; // Start with "All"
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'سجل المدفوعات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: Text('يرجى تسجيل الدخول')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          'سجل المدفوعات',
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue.shade700,
          labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'قيد المراجعة'),
            Tab(text: 'مقبولة'),
            Tab(text: 'مرفوضة'),
          ],
        ),
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: _paymentService.getPaymentHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    IconsaxPlusLinear.danger,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في تحميل البيانات',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final allPayments = snapshot.data ?? [];
          final payments = _selectedStatus == null
              ? allPayments
              : allPayments.where((p) => p.status == _selectedStatus).toList();

          if (payments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    IconsaxPlusLinear.wallet,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مدفوعات',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Force refresh by rebuilding
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                return _buildPaymentCard(payments[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (payment.status) {
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        statusText = 'قيد المراجعة';
        statusIcon = IconsaxPlusLinear.clock;
        break;
      case PaymentStatus.approved:
        statusColor = Colors.green;
        statusText = 'مقبولة';
        statusIcon = IconsaxPlusBold.tick_circle;
        break;
      case PaymentStatus.rejected:
        statusColor = Colors.red;
        statusText = 'مرفوضة';
        statusIcon = IconsaxPlusLinear.danger;
        break;
      case PaymentStatus.refunded:
        statusColor = Colors.blue;
        statusText = 'مستردة';
        statusIcon = IconsaxPlusLinear.wallet;
        break;
    }

    String methodText;
    IconData methodIcon;
    Color methodColor;

    switch (payment.method) {
      case PaymentMethod.stripe:
        methodText = 'Stripe';
        methodIcon = IconsaxPlusBold.card;
        methodColor = Colors.blue;
        break;
      case PaymentMethod.paymob:
        methodText = 'Paymob';
        methodIcon = IconsaxPlusBold.card;
        methodColor = Colors.green;
        break;
      case PaymentMethod.manual:
        methodText = 'محفظة إلكترونية';
        methodIcon = IconsaxPlusBold.wallet;
        methodColor = Colors.purple;
        break;
      case PaymentMethod.communication_fee:
        methodText = 'رسوم تواصل';
        methodIcon = IconsaxPlusBold.wallet;
        methodColor = Colors.teal;
        break;
      case PaymentMethod.cliq_a2a:
        methodText = 'CliQ';
        methodIcon = IconsaxPlusBold.wallet;
        methodColor = Colors.indigo;
        break;
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: methodColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(methodIcon, color: methodColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        methodText,
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(payment.createdAt),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المبلغ',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${payment.amount.toStringAsFixed(2)} ${payment.currency}',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Purpose
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الغرض',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'رسوم فتح التواصل',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),

            // Manual / wallet payment details
            if (payment.isManualPayment && payment.walletNumber != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طريقة الدفع',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    payment.method.name,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'رقم المحفظة',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    payment.walletNumber!,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
