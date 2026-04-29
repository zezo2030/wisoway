import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/theme/colors.dart';

class ShareLinkScreen extends StatefulWidget {
  final String tripId;

  const ShareLinkScreen({super.key, required this.tripId});

  @override
  State<ShareLinkScreen> createState() => _ShareLinkScreenState();
}

class _ShareLinkScreenState extends State<ShareLinkScreen> {
  bool _isLoading = true;
  String? _shareUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createShareLink();
  }

  Future<void> _createShareLink() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        ApiEndpoints.shareLink(widget.tripId),
      );
      final token = response['token'] as String?;
      if (token != null) {
        final baseUrl = ApiEndpoints.baseUrl;
        setState(() {
          _shareUrl = '$baseUrl/share/$token';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to create share link';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = ApiClient.mapError(e).displayMessage ?? ApiClient.mapError(e).messageKey;
        _isLoading = false;
      });
    }
  }

  void _shareLink() {
    if (_shareUrl != null) {
      Share.share(
        'Track my trip live: $_shareUrl',
        subject: 'Live Trip Tracking',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Trip')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            if (_isLoading) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Creating share link...'),
            ] else if (_error != null) ...[
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _createShareLink,
                child: const Text('Retry'),
              ),
            ] else ...[
              Text(
                'Share this link to let someone track your trip live.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _shareUrl ?? '',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.share),
                  label: const Text('Share Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
