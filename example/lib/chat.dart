import 'dart:io';
import 'package:chatly_plus/chatly_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.room,
  });

  final types.Room room;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isAttachmentUploading = false;

  // Constants for repeated strings
  static const String _photoText = 'Photo';
  static const String _fileText = 'File';
  static const String _cancelText = 'Cancel';
  static const String _editMessageTitle = 'Edit Message';
  static const String _editMessageHint = 'Edit your message';
  static const String _saveText = 'Save';
  static const String _noDataText = "No data";

  // Handles the attachment button press (shows a bottom sheet for file or image selection)
  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection(); // Open image picker
                },
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_photoText),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection(); // Open file picker
                },
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_fileText),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context), // Close the bottom sheet
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_cancelText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handles file selection and uploads the file to Firebase Storage
  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null && result.files.single.path != null) {
      _setAttachmentUploading(true); // Show loading indicator
      final file = File(result.files.single.path!);
      final name = result.files.single.name;

      try {
        // Upload file to Firebase Storage
        final reference = FirebaseStorage.instance.ref(name);
        await reference.putFile(file);
        final uri = await reference.getDownloadURL();

        // Create a file message and send it
        final message = types.PartialFile(
          mimeType: lookupMimeType(file.path),
          name: name,
          size: result.files.single.size,
          uri: uri,
        );

        ChatlyChatCore.instance.sendMessage(message, widget.room.id);
      } finally {
        _setAttachmentUploading(false); // Hide loading indicator
      }
    }
  }

  // Handles image selection and uploads the image to Firebase Storage
  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      _setAttachmentUploading(true); // Show loading indicator
      final file = File(result.path);
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      try {
        // Upload image to Firebase Storage
        final reference = FirebaseStorage.instance.ref(result.name);
        await reference.putFile(file);
        final uri = await reference.getDownloadURL();

        // Create an image message and send it
        final message = types.PartialImage(
          height: image.height.toDouble(),
          name: result.name,
          size: file.lengthSync(),
          uri: uri,
          width: image.width.toDouble(),
        );

        ChatlyChatCore.instance.sendMessage(message, widget.room.id);
      } finally {
        _setAttachmentUploading(false); // Hide loading indicator
      }
    }
  }

  // Handles tapping on a message (e.g., opening a file)
  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      // If the file is hosted online, download it locally
      if (message.uri.startsWith('http')) {
        try {
          final updatedMessage = message.copyWith(isLoading: true);
          ChatlyChatCore.instance.updateMessage(updatedMessage, widget.room.id);

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          // Save the file locally if it doesn't already exist
          if (!File(localPath).existsSync()) {
            await File(localPath).writeAsBytes(bytes);
          }
        } finally {
          final updatedMessage = message.copyWith(isLoading: false);
          ChatlyChatCore.instance.updateMessage(updatedMessage, widget.room.id);
        }
      }

      // Open the file using OpenFilex
      await OpenFilex.open(localPath);
    }
  }

  // Handles fetching preview data for links in messages
  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final updatedMessage = message.copyWith(previewData: previewData);
    ChatlyChatCore.instance.updateMessage(updatedMessage, widget.room.id);
  }

  // Handles sending a text message
  void _handleSendPressed(types.PartialText message) {
    ChatlyChatCore.instance.sendMessage(message, widget.room.id);
  }

  // Updates the state to show/hide the attachment upload indicator
  void _setAttachmentUploading(bool uploading) {
    setState(() {
      _isAttachmentUploading = uploading;
    });
  }

  // Shows a dialog to edit a message
  void _showEditMessageDialog(BuildContext context, types.Message message) {
    final TextEditingController _controller = TextEditingController();

    // Pre-fill the dialog with the current message text
    if (message is types.TextMessage) {
      _controller.text = message.text;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(_editMessageTitle),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: _editMessageHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close the dialog
              child: const Text(_cancelText),
            ),
            TextButton(
              onPressed: () {
                if (_controller.text.trim().isNotEmpty) {
                  _updateMessage(message, _controller.text.trim()); // Update the message
                  Navigator.pop(context); // Close the dialog
                }
              },
              child: const Text(_saveText),
            ),
          ],
        );
      },
    );
  }

  // Updates a message in the chat
  void _updateMessage(types.Message message, String newText) {
    if (message is types.TextMessage) {
      final updatedMessage = message.copyWith(
        text: newText,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        metadata: {
          ...message.metadata ?? {},
          'isEdited': true, // Mark the message as edited
        },
      );

      ChatlyChatCore.instance.updateMessage(updatedMessage, widget.room.id);
    }
  }

  // Marks messages as seen when the room is opened
  void _onRoomOpened(String roomId, List<types.Message> messages) async {
    for (final message in messages) {
      if (message.author.id != FirebaseAuth.instance.currentUser?.uid) {
        await ChatlyChatCore.instance.markMessageAsSeen(roomId, message.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(widget.room.name ?? ""),
      ),
      body: StreamBuilder<types.Room>(
        initialData: widget.room,
        stream: ChatlyChatCore.instance.room(widget.room.id),
        builder: (context, snapshot) => StreamBuilder<List<types.Message>>(
          initialData: const [],
          stream: ChatlyChatCore.instance.messages(snapshot.data!),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _onRoomOpened(widget.room.id, snapshot.data ?? []); // Mark messages as seen
              return Chat(
                usePreviewData: true,
                isAttachmentUploading: _isAttachmentUploading,
                messages: snapshot.data ?? [],
                onAttachmentPressed: _handleAttachmentPressed,
                onMessageTap: _handleMessageTap,
                onPreviewDataFetched: _handlePreviewDataFetched,
                dateHeaderBuilder: (p0) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: const Text("hehe"),
                    ),
                  );
                },
                onSendPressed: _handleSendPressed,
                onMessageLongPress: (context, message) {
                  if (message.author.id == FirebaseAuth.instance.currentUser?.uid) {
                    _showEditMessageDialog(context, message); // Show edit dialog
                  }
                },
                user: types.User(
                  id: FirebaseAuth.instance.currentUser?.uid ?? "",
                ),
                showUserNames: true,
                showUserAvatars: true,
                useTopSafeAreaInset: true,
                hideBackgroundOnEmojiMessages: false,
                isLeftStatus: false,
                customStatusBuilder: (message, {required context}) {
                  final isSeen = message.metadata?['seen'] == true;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSeen ? Icons.done_all : Icons.done,
                        size: 16,
                        color: isSeen ? Colors.indigo : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                    ],
                  );
                },
              );
            } else {
              return const Text(_noDataText);
            }
          },
        ),
      ),
    );
  }
}