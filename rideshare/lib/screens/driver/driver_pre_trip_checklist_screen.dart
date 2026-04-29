import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/colors.dart';

class DriverPreTripChecklistScreen extends StatefulWidget {
  final String bookingId;
  final List<Map<String, dynamic>> seats;

  const DriverPreTripChecklistScreen({
    super.key,
    required this.bookingId,
    required this.seats,
  });

  @override
  State<DriverPreTripChecklistScreen> createState() =>
      _DriverPreTripChecklistScreenState();
}

class _DriverPreTripChecklistScreenState
    extends State<DriverPreTripChecklistScreen> {
  bool _isLoading = false;
  final Map<String, bool> _presence = {};

  Future<void> _confirmSeat(String seatNumber, bool present) async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ApiClient();
      await apiClient.post(
        ApiEndpoints.driverConfirm(widget.bookingId),
        data: {'seatNumber': seatNumber, 'present': present},
      );
      setState(() => _presence[seatNumber] = present);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.mapError(e).displayMessage ?? ApiClient.mapError(e).messageKey)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Passengers')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.seats.length,
        itemBuilder: (context, index) {
          final seat = widget.seats[index];
          final seatNumber = seat['seatNumber'] as String? ?? '';
          final displayName = seat['displayName'] as String? ?? '';
          final confirmed = _presence[seatNumber];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Seat $seatNumber'),
                      ],
                    ),
                  ),
                  if (confirmed == true)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else if (confirmed == false)
                    const Icon(Icons.cancel, color: Colors.red)
                  else if (_isLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      tooltip: 'Present',
                      onPressed: () => _confirmSeat(seatNumber, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      tooltip: 'Absent',
                      onPressed: () => _confirmSeat(seatNumber, false),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
