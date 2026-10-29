import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/ui/error_surface.dart';

class PromoCodeField extends StatefulWidget {
  final double amount;
  final String currency;
  final String tripType;
  final ValueChanged<String?> onChanged;
  const PromoCodeField({
    super.key,
    required this.amount,
    required this.currency,
    required this.tripType,
    required this.onChanged,
  });
  @override
  State<PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends State<PromoCodeField> {
  final _controller = TextEditingController();
  Map<String, dynamic>? _quote;
  bool _busy = false;
  int _version = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PromoCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount ||
        oldWidget.currency != widget.currency) {
      _version++;
      _quote = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(null);
      });
    }
  }

  Future<void> _apply() async {
    final version = ++_version;
    final code = _controller.text.trim().toUpperCase();
    widget.onChanged(null);
    setState(() {
      _busy = true;
      _quote = null;
    });
    try {
      final response = await ApiClient().post(
        '/promotions/preview',
        data: {
          'code': code,
          'amount': double.parse(widget.amount.toStringAsFixed(2)),
          'tripType': widget.tripType,
        },
      );
      if (!mounted || version != _version) return;
      final data = Map<String, dynamic>.from(response['data'] ?? response);
      setState(() => _quote = data);
      widget.onChanged(code);
    } catch (e) {
      if (mounted && version == _version) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: 32,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: ar ? 'كود الخصم' : 'Promo code',
                    counterText: '',
                  ),
                  onChanged: (_) {
                    _version++;
                    setState(() => _quote = null);
                    widget.onChanged(null);
                  },
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : _apply,
                child: Text(ar ? 'تطبيق' : 'Apply'),
              ),
            ],
          ),
          if (_quote != null)
            Text(
              '${ar ? 'السعر' : 'Fare'}: ${_quote!['originalAmount']} ${widget.currency}\n${ar ? 'الخصم' : 'Discount'}: -${_quote!['discountAmount']} ${widget.currency}\n${ar ? 'المطلوب دفعه' : 'Amount due'}: ${_quote!['totalAmount']} ${widget.currency}',
            ),
        ],
      ),
    );
  }
}
