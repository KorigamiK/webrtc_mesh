import 'package:flutter_webrtc/flutter_webrtc.dart';

enum PeerConnectionState {
  new_,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

class PeerConnection {
  PeerConnectionState state;
  RTCPeerConnection? conn;
  RTCDataChannel? dataChannel;

  PeerConnection({this.state = PeerConnectionState.new_, this.conn});

  @override
  toString() {
    return 'PeerConnection: $state';
  }

  Future<void> dispose() async {
    await conn?.dispose();
    await dataChannel?.close();
  }
}
