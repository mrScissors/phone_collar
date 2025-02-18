import 'package:flutter/services.dart';

class CallEventChannel {
  static const EventChannel _eventChannel =
  EventChannel('com.example.phone_collar/incomingCallStream');

  /// Returns a stream of incoming call numbers.
  static Stream<String> get incomingCallStream {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as String);
  }
}
