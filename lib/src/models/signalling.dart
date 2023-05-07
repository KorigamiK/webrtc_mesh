import 'package:flutter/foundation.dart';

import 'message.dart' show SignalMessage;

abstract class Signalling<SignalMssageT extends SignalMessage> {
  final String roomID;
  final String localPeerID;

  /// Callback for when a message is received
  /// [onMessage] is the callback
  /// [SignalMssageT] is the type of message
  /// Not to be implemented by the user
  /// This is set by the [WebRTCMesh]
  Function(SignalMssageT)? onMessage;

  Signalling(this.roomID, this.localPeerID) {
    if (kDebugMode) print('Signalling: $roomID, $localPeerID');
  }

  void init() {
    createSignalStreamCallback();
  }

  void createSignalStreamCallback();

  /// Send a message to the signalling server and add it to the stream
  /// [type] is the type of message
  /// [message] is the message to send
  /// [announce] is whether to announce the message to the room
  Future<void> sendMessage(String type, Map<String, dynamic> message,
      {bool announce = false});
}
