import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

void main() {

  runApp(MyApp());

}

final ThemeData kIOSTheme = ThemeData(
  primarySwatch: Colors.orange,
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light,
);

final ThemeData kDefaultTheme = ThemeData(
  primarySwatch: Colors.purple,
  accentColor: Colors.orangeAccent[400],
); 

final googleSignIn = GoogleSignIn();
final auth = FirebaseAuth.instance;

Future<Null> _ensureLoggedIn() async {
  GoogleSignInAccount user = googleSignIn.currentUser;
  if (user == null) {
    user = await googleSignIn.signInSilently(suppressErrors: true);
  }
  if (user == null) {
    user = await googleSignIn.signIn();
  }
  if (await auth.currentUser() == null) {
    final GoogleSignInAuthentication googleAuth = await user.authentication;
    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await auth.signInWithCredential(credential);
  }
}

void _handleSubmitted(String text) async {
  await _ensureLoggedIn();
  _sendMessage(text: text);
}

void _sendMessage({String text, String imgUrl}) {
  Firestore.instance.collection("messages").add(
    {
      "text": text,
      "imgUrl": imgUrl,
      "senderName": googleSignIn.currentUser.displayName,
      "senderPhotoUrl": googleSignIn.currentUser.photoUrl,
      "created_at": DateTime.now()
    }
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Online',
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context).platform == TargetPlatform.iOS ?
        kIOSTheme : kDefaultTheme,
        home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  List<DocumentSnapshot> _orderList(List<DocumentSnapshot> list) {
    list.sort((a, b) {
      return b["created_at"].compareTo(a["created_at"]);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      top: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Chat App"),
          centerTitle: true,
          elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
        ),
        body: Column(
           children: <Widget>[
             Expanded(
               child: StreamBuilder(
                 stream: Firestore.instance.collection("messages").snapshots(),
                 builder: (context, snapshot) {
                   switch(snapshot.connectionState) {
                     case ConnectionState.none :
                     case ConnectionState.waiting :
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                     default:
                      return ListView.builder(
                        reverse: true,
                        itemCount: snapshot.data.documents.length,
                        itemBuilder: (context, index) {
                          List r = _orderList(snapshot.data.documents);
                          return ChatMessage(r[index].data);
                        },
                      );

                   }
                 },
               ),
             ),
             Divider(
               height: 1.0,
             ),
             Container(
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
               ),
               child: TextComposer(),
             ),
           ],
        ),
      ),
    );
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {

  TextEditingController _textController = TextEditingController();
  bool _isComposing = false;

  void _reset() {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(
        color: Theme.of(context).accentColor,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: Theme.of(context).platform == TargetPlatform.iOS ?
          BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[200]))
          ) : null,
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                icon: Icon(Icons.photo_camera),
                onPressed: () async {
                  await _ensureLoggedIn();
                  File imgFile = await ImagePicker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (imgFile == null) return;
                  StorageUploadTask task = FirebaseStorage.instance.ref().child(googleSignIn.currentUser.id.toString() +
                      DateTime.now().millisecondsSinceEpoch.toString()).putFile(imgFile);
                  StorageTaskSnapshot taskSnapshot = await task.onComplete;
                  String url = await taskSnapshot.ref.getDownloadURL();
                  _sendMessage(imgUrl: url);
                },
              ),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration.collapsed(hintText: "Enviar uma Mensagem"),
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.length > 0;
                  });
                },
                onSubmitted: (text) {
                  _handleSubmitted(text);
                  _reset();
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _getSendButton(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getSendButton(BuildContext context) {
    Widget sendButton;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      sendButton = CupertinoButton(
        child: Text("Enviar"),
        onPressed: _isComposing ? () {
          _handleSubmitted(_textController.text);
          _reset();
        } : null,
      );
    } else {
      sendButton = IconButton(
        icon: Icon(Icons.send),
        onPressed: _isComposing ? () {
          _handleSubmitted(_textController.text);
          _reset();
        } : null,
      );
    }
    return sendButton;
  }

}

class ChatMessage extends StatelessWidget {

  final Map<String, dynamic> data;

  ChatMessage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundImage: NetworkImage(this.data["senderPhotoUrl"]),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    this.data["senderName"],
                    style: Theme.of(context).textTheme.subhead,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: this.data["imgUrl"] != null ?
                      Image.network(this.data["imgUrl"], width: 250.0,) :
                        Text(this.data["text"]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}