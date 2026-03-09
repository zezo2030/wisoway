import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/payment_service.dart';
import '../../models/payment_model.dart';
import '../../models/wallet_model.dart';
import '../../providers/auth_provider.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  final PaymentService _paymentService = PaymentService();
  WalletModel? _wallet;
  List<PaymentModel> _transactions = [];
  bool _loading = true;
  bool _loadingTransactions = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final wallet = await _paymentService.getWalletMe();
      if (mounted) {
        setState(() {
          _wallet = wallet;
          _loading = false;
        });
      }
      _loadTransactions();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loadingTransactions = true);
    try {
      final res = await _paymentService.getWalletTransactions();
      final data = res['data'] as List? ?? [];
      final list = data
          .map((e) => PaymentModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _transactions = list;
          _loadingTransactions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTransactions = false);
    }
  }

  Future<void> _openTopUp() async {
    final result = await Navigator.pushNamed(
      context,
      RouteNames.driverWalletTopup,
    );
    if (result == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.userModel == null) {
      return Scaffold(
        appBar: AppBar(title: Text('المحفظة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
        body: const Center(child: Text('يرجى تسجيل الدخول')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text('المحفظة', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 16),
                    _buildFreeTripCard(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'سجل الحركات',
                          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _openTopUp,
                          icon: const Icon(IconsaxPlusLinear.add_circle, size: 20),
                          label: Text('شحن المحفظة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _loadingTransactions
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _transactions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'لا توجد حركات بعد',
                                    style: GoogleFonts.cairo(color: Colors.grey[600]),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _transactions.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final p = _transactions[i];
                                  return _buildTransactionTile(p);
                                },
                              ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTopUp,
        icon: const Icon(IconsaxPlusBold.wallet_add),
        label: Text('شحن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade600,
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _wallet?.balance ?? 0.0;
    final currency = _wallet?.currency ?? 'EGP';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(IconsaxPlusBold.wallet_3, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'رصيد المحفظة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${balance.toStringAsFixed(2)} $currency',
            style: GoogleFonts.cairo(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTripCard() {
    final used = _wallet?.hasUsedLifetimeFreeTrip ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: used ? Colors.grey[200] : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: used ? Colors.grey[400]! : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            used ? IconsaxPlusLinear.tick_circle : IconsaxPlusBold.gift,
            color: used ? Colors.grey[600] : Colors.green.shade700,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              used
                  ? 'تم استخدام الرحلة المجانية'
                  : 'لديك رحلة مجانية واحدة لفتح بيانات الركاب',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: used ? Colors.grey[700] : Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(PaymentModel p) {
    final isCredit = p.paymentType == 'wallet_topup';
    final isDebit = p.paymentType == 'wallet_trip_charge';
    final amount = p.amount;
    final prefix = isDebit ? '-' : '+';
    final color = isCredit ? Colors.green : Colors.orange;
    String label = p.paymentType == 'wallet_topup'
        ? 'شحن محفظة'
        : p.paymentType == 'wallet_trip_charge'
            ? 'رسوم رحلة'
            : p.paymentType;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? IconsaxPlusBold.wallet_add : IconsaxPlusBold.car,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${amount.toStringAsFixed(2)} ${p.currency}',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCredit ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
