import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import 'models/message.dart';
import 'models/signalling.dart';
import 'peer.dart';

void debugPrint(dynamic message) {
  if (kDebugMode) print(message);
}

/// Creates an instance of a generic type
/// https://stackoverflow.com/questions/23112130/creating-an-instance-of-a-generic-type-in-dart
typedef ItemCreator<S> = S Function(String roomId, String localPeerID);

/// The main class for WebRTC mesh
/// [ISignalling] is the type of signalling to be used
/// [SignalMessage] is the type of signalling message
class WebRTCMesh<ISignalling extends Signalling<SignalMessage>> {
  ItemCreator<ISignalling> signallingCreator;

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'}
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> offerOptions = {
    'offerToReceiveAudio': 0,
    'offerToReceiveVideo': 0,
  };

  final Map<String, PeerConnection> _peerConnections = {};
  final List<String> _connectingQueue = [];

  final String roomID;
  late final String localPeerID;
  late final ISignalling _signalling;

  void printPeers() {
    if (kDebugMode) {
      debugPrint('Peers: $_peerConnections');
      debugPrint('Connecting: $_connectingQueue');
    }
  }

  void dispose() {
    _signalling.sendMessage('leave', {}, announce: true);
    _signalling.onMessage = null;
    _connectingQueue.clear();
    _peerConnections
        .forEach((key, value) async => await _closePeerConnection(key));
    messageStream.close();
  }

  StreamController<Message> messageStream = StreamController<Message>();

  /// Sends a join announcement to all peers on the mesh
  WebRTCMesh(
      {required this.roomID, String? peerID, required this.signallingCreator}) {
    localPeerID = peerID ?? const Uuid().v4();
    _signalling = signallingCreator(roomID, localPeerID);
    _signalling.onMessage = onMessage;

    /// send joining announcement
    _signalling.sendMessage('join', {}, announce: true);
  }

  void _addPeer(String peerID) {
    if (_peerConnections.containsKey(peerID)) return;
    _peerConnections[peerID] = PeerConnection(); // new peer
    if (!_connectingQueue.contains(peerID)) {
      _connectingQueue.add(peerID);
    }
  }

  Future<void> _closePeerConnection(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    await _peerConnections[peerID]!.dispose();
    _peerConnections[peerID]!.state = PeerConnectionState.closed;
    _peerConnections.remove(peerID);
  }

  Future<void> _setDataChannel(String peerID) async {
    final pc = _peerConnections[peerID]!;
    debugPrint('creating data channel for $peerID');
    pc.dataChannel =
        await pc.conn!.createDataChannel('data', RTCDataChannelInit());
    pc.dataChannel!.onMessage = _handleDataChannelMessage(peerID);
    pc.dataChannel!.onDataChannelState = _handleDataChannelState(peerID);
  }

  /// Send a message to a peer
  Future<void> sendToPeer(String peerID, String message) async {
    final pc = _peerConnections[peerID]!;
    if (pc.dataChannel == null) {
      debugPrint('data channel not ready for $peerID');
      return;
    }
    debugPrint('sending to $peerID: $message');
    await pc.dataChannel!.send(RTCDataChannelMessage(jsonEncode(
        Message(type: 'message', message: message, from: localPeerID)
            .toJson())));
  }

  /// Send a message to all peers in the mesh
  Future<void> sendToAllPeers(String message) async {
    for (final peerID in _peerConnections.keys) {
      await sendToPeer(peerID, message);
    }
  }

  Future<void> _createOffer(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    final pc = _peerConnections[peerID]!;
    final offer = await pc.conn!.createOffer(offerOptions);
    await pc.conn!.setLocalDescription(offer);
    await _signalling.sendMessage('offer', {
      'sdp': offer.sdp,
      'type': offer.type,
      'to': peerID,
    });
  }

  Future<void> _connectPeer(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    debugPrint('connecting to $peerID');
    await _setDataChannel(peerID);
    await _createOffer(peerID);
  }

  Future<void> _createPeer(String peerID) async {
    if (_peerConnections[peerID]!.conn != null) {
      debugPrint('peer already exists');
    }

    final pc = _peerConnections[peerID]!;
    pc.conn = await createPeerConnection(configuration);
    pc.state = PeerConnectionState.connecting;

    pc.conn!.onIceCandidate = (candidate) async {
      if (candidate.candidate == null) return;
      debugPrint('sending answer with icecandidate to $peerID');
      await _signalling.sendMessage('candidate', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'to': peerID,
      });
    };

    pc.conn!.onIceConnectionState = (state) {
      debugPrint('onIceConnectionState: $state for $peerID');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          pc.state = PeerConnectionState.failed;
          pc.conn!.restartIce();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          debugPrint('disconnected $peerID');
          pc.state = PeerConnectionState.disconnected;
          _closePeerConnection(peerID);
          break;
        default:
          break;
      }
    };

    pc.conn!.onDataChannel = (channel) {
      debugPrint('onDataChannel: ${channel.label}');
      pc.dataChannel = channel;
      pc.dataChannel!.onMessage = _handleDataChannelMessage(peerID);
      pc.dataChannel!.onDataChannelState = _handleDataChannelState(peerID);
    };

    pc.conn!.onTrack = (event) {
      debugPrint('onTrack: ${event.track.id}');
    };
  }

  Function(RTCDataChannelMessage) _handleDataChannelMessage(String peerID) {
    final peer = _peerConnections[peerID]!;
    return (RTCDataChannelMessage message) {
      debugPrint('received: ${message.text}');
      Map<String, dynamic> data = jsonDecode(message.text);
      var msg = Message.fromJson(data);
      if (msg.type == 'handshake') {
        debugPrint('handshake from ${msg.from}');
        peer.state = PeerConnectionState.connected;
      }
      messageStream.add(msg);
    };
  }

  Function(RTCDataChannelState) _handleDataChannelState(String peerID) {
    final peer = _peerConnections[peerID]!;
    return (RTCDataChannelState state) {
      debugPrint('data channel state: $state');
      switch (state) {
        case RTCDataChannelState.RTCDataChannelOpen:
          debugPrint('data channel opened');
          peer.dataChannel!.send(RTCDataChannelMessage(
              jsonEncode(Message(from: peerID, type: 'handshake'))));
          break;
        case RTCDataChannelState.RTCDataChannelClosed:
          debugPrint('data channel closed');
          break;
        default:
          break;
      }
    };
  }

  /// Start connection signalling for all peers in the connectingQueue
  Future<void> _connect() async {
    while (_connectingQueue.isNotEmpty) {
      final peerID = _connectingQueue.removeAt(0);
      await _createPeer(peerID); // new peer in connecting state
      await _connectPeer(peerID); // initiate connection signalling
    }
  }

  Future<void> _handleOffer(String peerID, Map<String, dynamic> message) async {
    if (_peerConnections.containsKey(peerID)) {
      assert(_peerConnections[peerID]?.conn != null);
      final pc = _peerConnections[peerID]!;
      debugPrint('handling offer from $peerID');
      if ((await pc.conn!.getRemoteDescription()) == null) {
        await pc.conn!.setRemoteDescription(
          RTCSessionDescription(
            message['sdp'],
            message['type'],
          ),
        );
        final answer = await pc.conn!.createAnswer();
        await pc.conn!.setLocalDescription(answer);
        await _signalling.sendMessage('answer', {
          'sdp': answer.sdp,
          'type': answer.type,
          'to': peerID,
        });
      } else {
        debugPrint('offer:remote description already set');
      }
    } else {
      // create new peer and add to connecting queue
      debugPrint('adding $peerID to connecting queue');
      _addPeer(peerID);
      await _createPeer(peerID);
      await _handleOffer(peerID, message);
    }
  }

  Future<void> _handleAnswer(
      String peerID, Map<String, dynamic> message) async {
    if (!_peerConnections.containsKey(peerID)) return;
    final pc = _peerConnections[peerID]!;
    debugPrint('handling answer from $peerID');
    if ((await pc.conn?.getRemoteDescription()) == null) {
      await pc.conn!.setRemoteDescription(
        RTCSessionDescription(
          message['sdp'],
          message['type'],
        ),
      );
    } else {
      debugPrint('answer:remote description already set');
    }
  }

  Future<void> _handleCandidate(
      String peerID, Map<String, dynamic> message) async {
    if (!_peerConnections.containsKey(peerID)) return;
    final pc = _peerConnections[peerID]!;
    debugPrint('handling candidate from $peerID');
    if ((await pc.conn!.getRemoteDescription()) == null) {
      debugPrint('candidate:remote description not set yet');
      debugPrint(pc.conn != null);
      return;
    }
    await pc.conn!.addCandidate(
      RTCIceCandidate(
        message['candidate'],
        message['sdpMid'],
        message['sdpMLineIndex'],
      ),
    );
  }

  Future<void> _handleLeave(String peerID) async {
    if (!_peerConnections.containsKey(peerID)) return;
    debugPrint('handling leave from $peerID');
    await _closePeerConnection(peerID);
  }

  Future<void> onMessage(SignalMessage event) async {
    final peerID = event.from;
    if (peerID == localPeerID) return;
    final type = event.type;
    final message = event.message;
    switch (type) {
      case 'join':
        debugPrint('join from $peerID');
        _addPeer(peerID);
        await _connect();
        break;
      case 'offer':
        debugPrint('offer from $peerID to ${message['to']}]}');
        if (message['to'] == localPeerID) {
          await _handleOffer(peerID, message); // creaet answer
        }
        break;
      case 'answer':
        debugPrint('answer from $peerID');
        if (message['to'] == localPeerID) {
          await _handleAnswer(peerID, message); // set remote description
        }
        break;
      case 'candidate':
        debugPrint('candidate from $peerID to ${message['to']}');
        if (message['to'] == localPeerID) {
          await _handleCandidate(peerID, message); // add ice candidate
        }
        break;
      case 'leave':
        debugPrint('leave from $peerID');
        await _handleLeave(peerID);
        break;
      default:
        debugPrint('Unknown message type: $type');
    }
  }
}
