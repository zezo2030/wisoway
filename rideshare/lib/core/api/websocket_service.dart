import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../storage/token_storage.dart';
import 'api_endpoints.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IO.Socket? _chatSocket;
  IO.Socket? _tripsSocket;
  IO.Socket? _notificationsSocket;
  IO.Socket? _trackingSocket;
  final TokenStorage _tokenStorage = TokenStorage();

  // Streams for real-time events
  // Chat
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;

  // Trips
  final _tripUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTripUpdated =>
      _tripUpdateController.stream;

  // Bookings/Seats
  final _seatUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onSeatUpdated =>
      _seatUpdateController.stream;

  // Notifications
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;

  // Tracking
  final _trackingController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTrackingUpdate =>
      _trackingController.stream;

  // Initialize socket connection
  Future<void> connect() async {
    if ((_chatSocket != null && _chatSocket!.connected) &&
        (_tripsSocket != null && _tripsSocket!.connected) &&
        (_notificationsSocket != null && _notificationsSocket!.connected) &&
        (_trackingSocket != null && _trackingSocket!.connected)) {
      return;
    }

    final token = await _tokenStorage.getAccessToken();
    if (token == null) return;

    // Use baseUrl but remove /api/v1 to get the root domain
    final baseUrl = ApiEndpoints.baseUrl.replaceAll('/api/v1', '');

    IO.Socket createSocket(String namespace) => IO.io(
      '$baseUrl$namespace',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth({'token': token})
          .enableForceNew()
          .build(),
    );

    _chatSocket ??= createSocket('/chat');
    _tripsSocket ??= createSocket('/trips');
    _notificationsSocket ??= createSocket('/notifications');
    _trackingSocket ??= createSocket('/tracking');

    _chatSocket!.connect();
    _tripsSocket!.connect();
    _notificationsSocket!.connect();
    _trackingSocket!.connect();

    _chatSocket!.onConnect((_) => print('✅ Connected to Chat WS'));
    _tripsSocket!.onConnect((_) => print('✅ Connected to Trips WS'));
    _notificationsSocket!.onConnect((_) {
      print('✅ Connected to Notifications WS');
      _notificationsSocket!.emit('subscribe');
    });
    _trackingSocket!.onConnect((_) => print('✅ Connected to Tracking WS'));

    // Listen to Chat events
    _chatSocket!.on('newMessage', (data) {
      _messageController.add(data);
    });

    // Listen to Trip events
    _tripsSocket!.on('tripUpdated', (data) {
      _tripUpdateController.add(data);
    });

    // Listen to Seat/Booking events
    _tripsSocket!.on('seatBooked', (data) {
      _seatUpdateController.add(data);
    });

    _tripsSocket!.on('seatReleased', (data) {
      _seatUpdateController.add(data);
    });

    // Listen to Notification events
    _notificationsSocket!.on('newNotification', (data) {
      _notificationController.add(Map<String, dynamic>.from(data));
    });

    // Listen to Tracking events
    _trackingSocket!.on('trip:tracking:update', (data) {
      _trackingController.add(Map<String, dynamic>.from(data));
    });
    _trackingSocket!.on('trip:tracking:snapshot', (data) {
      _trackingController.add(Map<String, dynamic>.from(data));
    });
  }

  // Join specific chat room / trip room
  void joinRoom(String roomId) {
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emit('joinRoom', {'chatRoomId': roomId});
    }
  }

  // Leave specific room
  void leaveRoom(String roomId) {
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emit('leaveRoom', {'chatRoomId': roomId});
    }
  }

  // Send a message directly via socket (optional if using REST)
  void sendMessage(String roomId, String text) {
    if (_chatSocket != null && _chatSocket!.connected) {
      _chatSocket!.emit('sendMessage', {'chatRoomId': roomId, 'text': text});
    }
  }

  // Subscribe to trip updates (like checking seats map)
  void subscribeToTrip(String tripId) {
    if (_tripsSocket != null && _tripsSocket!.connected) {
      _tripsSocket!.emit('subscribeTripUpdates', {'tripId': tripId});
    }
  }

  void unsubscribeFromTrip(String tripId) {
    if (_tripsSocket != null && _tripsSocket!.connected) {
      _tripsSocket!.emit('unsubscribeTripUpdates', {'tripId': tripId});
    }
  }

  void subscribeToTripTracking(String tripId) {
    if (_trackingSocket != null && _trackingSocket!.connected) {
      _trackingSocket!.emit('trip:tracking:subscribe', {'tripId': tripId});
    }
  }

  void unsubscribeFromTripTracking(String tripId) {
    if (_trackingSocket != null && _trackingSocket!.connected) {
      _trackingSocket!.emit('trip:tracking:unsubscribe', {'tripId': tripId});
    }
  }

  void updateDriverLocation({
    required String tripId,
    required double latitude,
    required double longitude,
    double? speedKph,
    double? heading,
    double? accuracyMeters,
  }) {
    if (_trackingSocket != null && _trackingSocket!.connected) {
      _trackingSocket!.emit('driver:location:update', {
        'tripId': tripId,
        'latitude': latitude,
        'longitude': longitude,
        'speedKph': speedKph,
        'heading': heading,
        'accuracyMeters': accuracyMeters,
      });
    }
  }

  // Disconnect & cleanup
  void disconnect() {
    _chatSocket?.disconnect();
    _chatSocket?.dispose();
    _chatSocket = null;

    _tripsSocket?.disconnect();
    _tripsSocket?.dispose();
    _tripsSocket = null;

    _notificationsSocket?.disconnect();
    _notificationsSocket?.dispose();
    _notificationsSocket = null;

    _trackingSocket?.disconnect();
    _trackingSocket?.dispose();
    _trackingSocket = null;
  }
}
