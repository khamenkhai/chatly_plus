# chatly_plus

**chatly_plus** is an improved version of Flyer Chat, adding a **"seen"** feature for real-time messaging. This package provides a seamless way to track message read receipts in Flutter apps.

## ✨ Features
- ✅ **Real-time Chat** - Send and receive messages instantly.
- ✅ **"Seen" Indicators** - Know when messages are read.
- ✅ **Firebase Firestore Integration** - Fully compatible with Firestore.
- ✅ **User Presence** - Track online and offline status.
- ✅ **Customizable UI** - Easily adjust chat UI elements.
- ✅ **Group & Private Chat Support** - Engage in one-on-one and group conversations.
- ✅ **Optimized for Performance** - Lightweight and efficient.
- ✅ **Secure & Scalable** - Built with Firebase security rules.

## 📥 Installation
Add this to your `pubspec.yaml`:
```yaml
dependencies:
  chatly_plus: ^0.0.1
```
Then run:
```sh
flutter pub get
```

## 🛠️ Usage
Import the package:
```dart
import 'package:chatly_plus/chatly_plus.dart';
```

### Initialize Chatly Plus
Ensure Firebase is initialized before using Chatly Plus:
```dart
await Firebase.initializeApp();
ChatlyChatCore.instance.init();
```

### Display Chat Rooms
```dart
ChatlyChatCore.instance.rooms().listen((rooms) {
  // Handle rooms list
});
```

### Send a Message
```dart
ChatlyChatCore.instance.sendMessage(
  roomId: "room_id",
  text: "Hello there!",
);
```

### Check Message Read Status
```dart
bool isSeen = message.isSeen;
```

## 🎨 Customization
You can customize the chat UI by modifying colors, fonts, and message bubbles. Example:
```dart
ChatTheme theme = ChatTheme(
  primaryColor: Colors.blue,
  backgroundColor: Colors.white,
);
```

## 📖 Documentation
For full documentation, visit [GitHub](https://github.com/your-repo/chatly_plus).

## ❤️ Contributing
We welcome contributions! Feel free to fork the repo and submit PRs.

## 📜 License
This package is licensed under MIT. See `LICENSE` for details.

## ✨ Support
If you find this package useful, please ⭐ the [GitHub repository](https://github.com/your-repo/chatly_plus).
