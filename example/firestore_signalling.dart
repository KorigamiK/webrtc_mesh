import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webrtc_mesh/webrtc_mesh.dart';

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
    init();
  }

  @override
  Future<void> sendMessage(String type, Map<String, dynamic> message,
      {bool announce = false}) async {
    final signalMessage = SignalMessage(
      type: type,
      message: message,
      from: localPeerID,
    );
    await _roomCollection.add(signalMessage.toJson());
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
