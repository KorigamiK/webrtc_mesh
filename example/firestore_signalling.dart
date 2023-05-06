import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:webrtc_mesh/src/models/message.dart';
import 'package:webrtc_mesh/src/models/signalling.dart';

class FirestoreSignalling extends Signalling<SignalMessage> {
  late final CollectionReference _roomCollection;

  FirestoreSignalling({
    required roomId,
    required localPeerID,
  }) : super(roomId, localPeerID) {
    _roomCollection = FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomID)
        .collection('messages');
  }

  @override
  Future<void> sendMessage(String type, dynamic message,
      {bool announce = false}) {
    return _roomCollection.add(Message(
      type: type,
      message: message,
      from: localPeerID,
    ).toJson());
  }

  @override
  void createSignalStreamCallback() {
    _roomCollection
        .where('timestamp',
            isGreaterThan: DateTime.now().millisecondsSinceEpoch)
        .snapshots()
        .listen((event) {
      for (var element in event.docChanges) {
        if (element.type == DocumentChangeType.added) {
          final message = SignalMessage.fromJson(
              element.doc.data() as Map<String, dynamic>);
          onMessage?.call(message);
        }
      }
    });
  }
}
