import 'package:flutter/material.dart';
import 'package:webrtc_mesh/webrtc_mesh.dart';
import 'firestore_signalling.dart';

dynamic main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "WebRTC Mesh Example",
        home: ChatScreen(roomId: 'roomId'),
      );
}

class ChatScreen extends StatefulWidget {
  final String roomId;
  final WebRTCMesh webRTCMesh;

  ChatScreen({Key? key, required this.roomId})
      : webRTCMesh = WebRTCMesh<FirestoreSignalling>(
          roomID: 'roomId',
          signallingCreator: (roomId, localPeerID) =>
              FirestoreSignalling(roomId: roomId, localPeerID: localPeerID),
        ),
        super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <Message>[];
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    widget.webRTCMesh.dispose();
  }

  void _sendMessage(String message) {
    widget.webRTCMesh.printPeers();
    final message = _textController.text.trim();
    if (message.isNotEmpty) {
      widget.webRTCMesh.sendToAllPeers(message);
      widget.webRTCMesh.messageStream.add(Message(
        message: message,
        type: 'text',
        from: widget.webRTCMesh.localPeerID,
      ));
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              widget.webRTCMesh.printPeers();
            },
          ),
        ],
        title: Row(
          children: [
            Text('Room ${widget.roomId}',
                style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<Message>(
              stream: widget.webRTCMesh.messageStream.stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text('No messages yet'),
                  );
                }

                _messages.add(snapshot.data!);

                return ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final message = _messages[index];
                    return ListTile(
                      title: Text(message.message ?? ''),
                      subtitle: Text(message.from),
                      trailing: Text(message.type),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your message',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(_textController.text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
