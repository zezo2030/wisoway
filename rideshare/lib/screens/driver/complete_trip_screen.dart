import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/colors.dart';

class CompleteTripScreen extends StatefulWidget {
  final String tripId;
  final String tripToName;
  final List<Map<String, dynamic>> bookings;

  const CompleteTripScreen({
    super.key,
    required this.tripId,
    required this.tripToName,
    required this.bookings,
  });

  @override
  State<CompleteTripScreen> createState() => _CompleteTripScreenState();
}

class _CompleteTripScreenState extends State<CompleteTripScreen> {
  bool _isLoading = false;
  final Set<String> _noShowSeatKeys = {};

  String _seatKey(String bookingId, String seatNumber) =>
      '$bookingId:$seatNumber';

  Future<void> _completeTrip() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ApiClient();
      final noShowSeats = _noShowSeatKeys.map((key) {
        final parts = key.split(':');
        return {'bookingId': parts[0], 'seatNumber': parts.sublist(1).join(':')};
      }).toList();

      await apiClient.post(
        ApiEndpoints.startTrip(widget.tripId).replaceAll('/start', '/complete'),
        data: {'noShowSeats': noShowSeats},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip completed')),
        );
        Navigator.of(context).pop(true);
      }
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
      appBar: AppBar(title: const Text('Complete Trip')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Mark absent passengers for trip to ${widget.tripToName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.bookings.length,
              itemBuilder: (context, index) {
                final booking = widget.bookings[index];
                final bookingId = booking['id'] as String? ?? '';
                final seats = booking['seats'] as List<dynamic>? ?? [];
                final userName = booking['user']?['name'] as String? ??
                    booking['userId'] as String? ??
                    '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...seats.map<Widget>((seat) {
                          final seatNum = seat['seatNumber'] as String? ?? '';
                          final displayName =
                              seat['displayName'] as String? ?? seatNum;
                          final key = _seatKey(bookingId, seatNum);
                          final isNoShow = _noShowSeatKeys.contains(key);

                          return CheckboxListTile(
                            value: isNoShow,
                            title: Text(displayName),
                            subtitle: Text('Seat $seatNum'),
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _noShowSeatKeys.add(key);
                                } else {
                                  _noShowSeatKeys.remove(key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _completeTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Complete Trip', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
