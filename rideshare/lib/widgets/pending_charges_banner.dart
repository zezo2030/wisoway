import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/booking/booking_bloc.dart';
import '../bloc/booking/booking_event.dart';
import '../bloc/booking/booking_state.dart';
import '../core/theme/colors.dart';

/// Banner that loads and displays outstanding pending charges for the current
/// user. Shown above booking lists and trip-detail screens.
///
/// The widget is self-contained: it fires [BookingLoadPendingCharges] on mount
/// and rebuilds when the [BookingBloc] transitions to
/// [BookingPendingChargesLoaded]. If there are no charges it renders nothing.
///
/// Usage — just drop it at the top of any relevant screen body:
/// ```dart
/// Column(
///   children: [
///     const PendingChargesBanner(),
///     Expanded(child: ...),
///   ],
/// )
/// ```
///
/// Phase 4 / T084 — 008-platform-completion.
class PendingChargesBanner extends StatefulWidget {
  const PendingChargesBanner({super.key});

  @override
  State<PendingChargesBanner> createState() => _PendingChargesBannerState();
}

class _PendingChargesBannerState extends State<PendingChargesBanner> {
  List<Map<String, dynamic>> _charges = [];

  @override
  void initState() {
    super.initState();
    // Fire the load event; BLoC is expected to be provided by an ancestor.
    context.read<BookingBloc>().add(const BookingLoadPendingCharges());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingPendingChargesLoaded) {
          setState(() => _charges = state.charges);
        }
      },
      child: _charges.isEmpty
          ? const SizedBox.shrink()
          : _PendingChargesCard(charges: _charges),
    );
  }
}

class _PendingChargesCard extends StatelessWidget {
  final List<Map<String, dynamic>> charges;

  const _PendingChargesCard({required this.charges});

  static String _kindLabel(String? kind) {
    switch (kind) {
      case 'late_cancellation':
        return 'إلغاء متأخر';
      case 'passenger_no_show':
        return 'غياب عن الرحلة';
      case 'driver_no_show':
        return 'غياب السائق';
      default:
        return kind ?? 'غرامة';
    }
  }

  static String _fmtAmount(dynamic amount, dynamic currency) {
    final a = amount is num ? amount.toStringAsFixed(2) : '$amount';
    return '$a ${currency ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = charges.fold<double>(
      0.0,
      (sum, c) {
        final a = c['amount'];
        return sum + (a is num ? a.toDouble() : 0.0);
      },
    );
    final currency = charges.isNotEmpty ? charges.first['currency'] : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.warning_amber_rounded,
            color: AppColors.warning, size: 22),
        title: Text(
          'لديك ${charges.length} غرامة معلقة'
          ' — ${_fmtAmount(totalAmount, currency)}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          'ستُخصم من محفظتك عند تأكيد حجزك التالي',
          style: TextStyle(fontSize: 12),
        ),
        children: [
          ...charges.map((c) {
            return ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_long_outlined, size: 18),
              title: Text(_kindLabel(c['kind']?.toString())),
              trailing: Text(
                _fmtAmount(c['amount'], c['currency']),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
