# WebRTC Mesh

An easy cross-platform WebRTC mesh network api.

## Features

- [x] Cross-platform
- [x] Custom Signalling Server support (including Firestore)
- [x] Multiple Rooms
- [x] Data Channel streams
- [x] Automatic connection/disconnection handling  

## Usage

Check the `/example` folder for a full example.

For a completed group chat example, check out [WebRTCMesh-GC](https://github.com/KorigamiK/WebRTCMesh-GC)

A simple chat app example:

```dart
import 'package:flutter/material.dart';
import 'package:webrtc_mesh/webrtc_mesh.dart';

import 'firestore_signalling.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            )
          ),
        ],
      ),
    );
  }
}
```

## Additional information

This is an overview of the signalling for WebRTC Mesh network protocol.

![WebRTC Signalling](https://raw.githubusercontent.com/KorigamiK/WebRTCMesh-GC/main/.github/webrtc.svg)