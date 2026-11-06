import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/services/payment_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/payment_model.dart';

/// What the top-up form does once the customer leaves this screen.
enum CliqTopupOutcome { credited, retry }

enum _Stage { waiting, credited, failed, timedOut }

/// Follows a CliQ top-up while the customer approves it in their bank app.
///
/// Leaving never cancels anything: the backend keeps following the payment,
/// credits the wallet and notifies the customer.
class CliqTopupWaitingScreen extends StatefulWidget {
  const CliqTopupWaitingScreen({
    super.key,
    required this.payment,
    required this.account,
    this.paymentService,
    this.now = DateTime.now,
  });

  static const approvalWindow = Duration(minutes: 5);
  static const _pollEverySeconds = 5;

  final PaymentModel payment;

  /// The CliQ alias or mobile number the request went to.
  final String account;
  final PaymentService? paymentService;
  final DateTime Function() now;

  @override
  State<CliqTopupWaitingScreen> createState() => _CliqTopupWaitingScreenState();
}

class _CliqTopupWaitingScreenState extends State<CliqTopupWaitingScreen>
    with WidgetsBindingObserver {
  late final PaymentService _payments =
      widget.paymentService ?? PaymentService();

  /// Wall-clock, so time spent in the bank app counts even if timers pause.
  late final DateTime _deadline;

  Timer? _ticker;
  int _ticks = 0;
  _Stage _stage = _Stage.waiting;
  Duration _remaining = CliqTopupWaitingScreen.approvalWindow;
  bool _checking = false;
  bool _checkingOnRequest = false;
  String? _hint;
  String? _failureNote;
  double? _newBalance;

  @override
  void initState() {
    super.initState();
    _deadline = widget.now().add(CliqTopupWaitingScreen.approvalWindow);
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _stage == _Stage.waiting) {
      _updateRemaining();
      if (_stage == _Stage.waiting) _check();
    }
  }

  void _tick() {
    if (_stage != _Stage.waiting) return;
    _updateRemaining();
    _ticks++;
    if (_stage == _Stage.waiting &&
        _ticks % CliqTopupWaitingScreen._pollEverySeconds == 0) {
      _check();
    }
  }

  void _updateRemaining() {
    final left = _deadline.difference(widget.now());
    if (left > Duration.zero) {
      setState(() => _remaining = left);
      return;
    }
    _ticker?.cancel();
    setState(() {
      _remaining = Duration.zero;
      _stage = _Stage.timedOut;
      _hint = null;
    });
    _check();
  }

  Future<void> _check({bool onRequest = false}) async {
    if (_checking) return;
    _checking = true;
    if (onRequest) setState(() => _checkingOnRequest = true);
    String? hint;
    try {
      final updated = await _payments.refreshCliqPaymentStatus(
        widget.payment.id,
      );
      if (!mounted) return;
      if (updated.status == PaymentStatus.approved) {
        await _onCredited();
        return;
      }
      if (updated.status == PaymentStatus.rejected) {
        _onFailed(updated.adminNote);
        return;
      }
      if (onRequest) hint = context.l10n.cliqNotConfirmedYet;
    } catch (_) {
      if (!mounted) return;
      hint = context.l10n.cliqConnectionRetrying;
    } finally {
      _checking = false;
    }
    setState(() {
      _checkingOnRequest = false;
      _hint = hint;
    });
  }

  Future<void> _onCredited() async {
    _ticker?.cancel();
    setState(() {
      _stage = _Stage.credited;
      _checkingOnRequest = false;
      _hint = null;
    });
    try {
      final account = await _payments.getWalletAccountMe();
      if (mounted) setState(() => _newBalance = account.balance);
    } catch (_) {
      // The top-up is done; the wallet screen shows the balance anyway.
    }
  }

  void _onFailed(String? note) {
    _ticker?.cancel();
    final trimmed = note?.trim() ?? '';
    setState(() {
      _stage = _Stage.failed;
      _checkingOnRequest = false;
      _hint = null;
      _failureNote = trimmed.isEmpty ? null : trimmed;
    });
  }

  void _leave() {
    Navigator.pop(
      context,
      _stage == _Stage.credited ? CliqTopupOutcome.credited : null,
    );
  }

  String _money(double value) =>
      '${value.toStringAsFixed(2)} ${widget.payment.currency}';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: switch (_stage) {
                  _Stage.waiting => _buildWaiting(),
                  _Stage.credited => _buildCredited(),
                  _Stage.failed => _buildFailed(),
                  _Stage.timedOut => _buildTimedOut(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    return _StageLayout(
      icon: IconsaxPlusBold.mobile,
      iconColor: T.primary(context),
      title: context.l10n.cliqApproveInBankTitle,
      body: context.l10n.cliqApproveInBankBody,
      details: _buildDetails(),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.cliqTimeRemaining,
            style: AppTextStyles.bodySmall.copyWith(
              color: T.onSurfaceVariant(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _clock(_remaining),
            key: const Key('cliq-countdown'),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineMedium.copyWith(
              color: T.onSurface(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          _buildCheckButton(context.l10n.cliqPaidCheckNow),
          const SizedBox(height: 12),
          Text(
            _hint ?? context.l10n.cliqKeepsFollowing,
            style: AppTextStyles.bodySmall.copyWith(
              color: T.onSurfaceVariant(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCredited() {
    final balance = _newBalance;
    return _StageLayout(
      icon: IconsaxPlusBold.tick_circle,
      iconColor: T.success(context),
      title: context.l10n.walletToppedUpViaCliq,
      details: _Details(
        rows: [
          (context.l10n.cliqAmountLabel, _money(widget.payment.amount)),
          if (balance != null) (context.l10n.cliqNewBalance, _money(balance)),
        ],
      ),
      footer: _buildPrimaryButton(context.l10n.cliqBackToWallet, _leave),
    );
  }

  Widget _buildFailed() {
    return _StageLayout(
      icon: IconsaxPlusBold.close_circle,
      iconColor: T.error(context),
      title: context.l10n.cliqPaymentFailed,
      body: _failureNote ?? context.l10n.cliqNotCredited,
      details: _buildDetails(),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPrimaryButton(
            context.l10n.retry,
            () => Navigator.pop(context, CliqTopupOutcome.retry),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _leave,
            child: Text(context.l10n.cliqBackToWallet),
          ),
        ],
      ),
    );
  }

  Widget _buildTimedOut() {
    return _StageLayout(
      icon: IconsaxPlusBold.clock,
      iconColor: AppColors.warning,
      title: context.l10n.cliqNotConfirmedTitle,
      body: context.l10n.cliqNotConfirmedBody,
      details: _buildDetails(),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCheckButton(context.l10n.cliqCheckNow),
          if (_hint != null) ...[
            const SizedBox(height: 12),
            Text(
              _hint!,
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onSurfaceVariant(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: _leave,
            child: Text(context.l10n.cliqBackToWallet),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return _Details(
      rows: [
        (context.l10n.cliqAmountLabel, _money(widget.payment.amount)),
        (context.l10n.cliqAccountLabel, widget.account),
      ],
    );
  }

  Widget _buildCheckButton(String label) {
    return _buildPrimaryButton(
      label,
      _checkingOnRequest ? null : () => _check(onRequest: true),
      busy: _checkingOnRequest,
    );
  }

  Widget _buildPrimaryButton(
    String label,
    VoidCallback? onPressed, {
    bool busy = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal700,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: busy
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.white,
              ),
            )
          : Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  static String _clock(Duration left) {
    // Rounded up so the clock never shows 00:00 with time still running.
    final seconds = (left.inMilliseconds / 1000).ceil();
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }
}

class _StageLayout extends StatelessWidget {
  const _StageLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.details,
    required this.footer,
    this.body,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? body;
  final Widget details;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 72, color: iconColor),
        const SizedBox(height: 20),
        Text(
          title,
          style: AppTextStyles.titleLarge.copyWith(
            color: T.onSurface(context),
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.onSurfaceVariant(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        details,
        const SizedBox(height: 24),
        footer,
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  row.$1,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    row.$2,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.end,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: T.onSurface(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
