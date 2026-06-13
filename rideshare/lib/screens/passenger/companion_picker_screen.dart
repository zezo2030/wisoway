import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../bloc/booking/booking_bloc.dart';
import '../../bloc/booking/booking_event.dart';
import '../../bloc/booking/booking_state.dart';
import '../../core/api/api_client.dart';
import '../../core/services/booking_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../models/booking_model.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/l10n_extensions.dart';

/// Full-screen companion picker for multi-seat bookings.
///
/// Shows a seat-count stepper followed by a form row per passenger.
/// Submits via [BookingBloc] using either [BookingCreateMultiSeat] (manual)
/// or [BookingAutoPick] (auto-pick).
///
/// Pops with a [BookingModel] on success, or null if the user cancels.
///
/// Phase 4 / T082 — 008-platform-completion.
class CompanionPickerScreen extends StatefulWidget {
  final TripModel trip;

  /// Seat numbers the user already has locked / selected (from the seat layout
  /// screen). Pass an empty list if coming from the auto-pick flow.
  final List<String> lockedSeatNumbers;

  /// Whether to use auto-pick instead of specific seat numbers.
  final bool autoPick;

  const CompanionPickerScreen({
    super.key,
    required this.trip,
    this.lockedSeatNumbers = const [],
    this.autoPick = false,
  });

  @override
  State<CompanionPickerScreen> createState() => _CompanionPickerScreenState();
}

class _CompanionPickerScreenState extends State<CompanionPickerScreen> {
  final _formKey = GlobalKey<FormState>();
  int _seatCount = 1;
  bool _sharePhone = true;

  // Row data — index 0 is the main booker.
  late List<_PassengerRowData> _rows;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.userModel;
    _rows = [
      _PassengerRowData(
        nameCtrl: TextEditingController(text: user?.name ?? ''),
        gender: user?.gender ?? 'male',
        isMainBooker: true,
      ),
    ];
    if (!widget.autoPick && widget.lockedSeatNumbers.isNotEmpty) {
      _seatCount = widget.lockedSeatNumbers.length;
      _syncRows();
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.nameCtrl.dispose();
    }
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _syncRows() {
    while (_rows.length < _seatCount) {
      _rows.add(
        _PassengerRowData(
          nameCtrl: TextEditingController(),
          gender: 'male',
          isMainBooker: false,
        ),
      );
    }
    while (_rows.length > _seatCount) {
      _rows.last.nameCtrl.dispose();
      _rows.removeLast();
    }
  }

  /// Upper bound is whatever the trip currently has free. No artificial cap —
  /// a passenger can book the whole car if they want.
  int get _maxSeats {
    final available = widget.trip.availableSeats;
    return available > 0 ? available : 1;
  }

  void _incrementSeat() {
    if (_seatCount >= _maxSeats) return;
    setState(() {
      _seatCount++;
      _syncRows();
    });
  }

  void _decrementSeat() {
    if (_seatCount <= 1) return;
    setState(() {
      _seatCount--;
      _syncRows();
    });
  }

  List<BookingSeatRequest> _buildRequests() {
    return List.generate(_rows.length, (i) {
      final r = _rows[i];
      final seatNumber = i < widget.lockedSeatNumbers.length
          ? widget.lockedSeatNumbers[i]
          : '${i + 1}'; // placeholder; auto-pick ignores this
      return BookingSeatRequest(
        seatNumber: seatNumber,
        displayName: r.nameCtrl.text.trim(),
        gender: r.gender,
        isMainBooker: r.isMainBooker,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final passengers = _buildRequests();

    if (widget.autoPick) {
      context.read<BookingBloc>().add(
            BookingAutoPick(
              tripId: widget.trip.id,
              seatCount: _seatCount,
              passengers: passengers,
              sharePhoneWithDriver: _sharePhone,
            ),
          );
    } else {
      context.read<BookingBloc>().add(
            BookingCreateMultiSeat(
              tripId: widget.trip.id,
              seats: passengers,
              sharePhoneWithDriver: _sharePhone,
            ),
          );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.bookingRequestSentWaitConfirm),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(state.booking);
        } else if (state is BookingError) {
          ErrorSurface.showFailure(
            context,
            state.failure ??
                ApiClient.mapError(Exception(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.autoPick
                ? context.l10n.autoPickTitle
                : context.l10n.passengerDataTitle,
          ),
        ),
        body: BlocBuilder<BookingBloc, BookingState>(
          builder: (context, state) {
            final isLoading = state is BookingLoading;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Trip summary ───────────────────────────────────────
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.trip.from.name} ← ${widget.trip.to.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.pricePerSeatValue(
                              '${widget.trip.price}',
                              widget.trip.currency,
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Seat count stepper (auto-pick or extra seats) ──────
                  if (widget.autoPick) ...[
                    Text(
                      context.l10n.seatCountLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SeatCountStepper(
                      count: _seatCount,
                      maxCount: _maxSeats,
                      onIncrement: _incrementSeat,
                      onDecrement: _decrementSeat,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Passenger rows ────────────────────────────────────
                  Text(
                    context.l10n.passengerDataTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_rows.length, (i) {
                    final isMain = i == 0;
                    return _PassengerFormRow(
                      index: i,
                      data: _rows[i],
                      label: isMain
                          ? context.l10n.mainBookerLabel
                          : context.l10n.companionLabel(i),
                      readOnlyName: isMain,
                      onGenderChanged: (g) {
                        setState(() => _rows[i].gender = g);
                      },
                    );
                  }),

                  const SizedBox(height: 16),

                  // ── Share phone toggle ─────────────────────────────────
                  Card(
                    child: SwitchListTile(
                      title: Text(context.l10n.sharePhoneWithDriver),
                      subtitle: Text(context.l10n.sharePhoneWithDriverSubtitle),
                      value: _sharePhone,
                      onChanged: (v) => setState(() => _sharePhone = v),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Submit button ──────────────────────────────────────
                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            context.l10n.sendBookingRequest,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PassengerRowData {
  final TextEditingController nameCtrl;
  String gender;
  final bool isMainBooker;

  _PassengerRowData({
    required this.nameCtrl,
    required this.gender,
    required this.isMainBooker,
  });
}

class _PassengerFormRow extends StatelessWidget {
  final int index;
  final _PassengerRowData data;
  final String label;
  final bool readOnlyName;
  final void Function(String gender) onGenderChanged;

  const _PassengerFormRow({
    required this.index,
    required this.data,
    required this.label,
    required this.onGenderChanged,
    this.readOnlyName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: data.nameCtrl,
                readOnly: readOnlyName,
                decoration: InputDecoration(
                  labelText: context.l10n.name,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.nameRequired
                    : null,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'male',
                    label: Text(context.l10n.male),
                  ),
                  ButtonSegment(
                    value: 'female',
                    label: Text(context.l10n.female),
                  ),
                ],
                selected: {data.gender},
                onSelectionChanged: readOnlyName
                    ? null
                    : (s) => onGenderChanged(s.first),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeatCountStepper extends StatelessWidget {
  final int count;
  final int maxCount;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _SeatCountStepper({
    required this.count,
    required this.maxCount,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: count > 1 ? onDecrement : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton.outlined(
          onPressed: count < maxCount ? onIncrement : null,
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: 12),
        Text(
          context.l10n.seatWord,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
