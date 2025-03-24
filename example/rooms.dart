import 'package:chatly_plus/chatly_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'chat.dart';
import 'login.dart';
import 'users.dart';
import 'util.dart';

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  bool _error = false; // Tracks if an error occurred during initialization
  bool _initialized = false; // Tracks if Firebase is initialized
  User? _user; // Stores the current authenticated user

  @override
  void initState() {
    initializeFlutterFire(); // Initialize Firebase when the widget is created
    super.initState();
  }

  // Initializes Firebase and listens for authentication state changes
  void initializeFlutterFire() async {
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        setState(() {
          _user = user; // Update the user state when authentication changes
        });
      });
      setState(() {
        _initialized = true; // Mark Firebase as initialized
      });
    } catch (e) {
      setState(() {
        _error = true; // Set error state if initialization fails
      });
    }
  }

  // Logs out the current user
  void logout() async {
    await FirebaseAuth.instance.signOut(); // Sign out from Firebase
    setState(() {
      _user = null; // Clear the user state
    });
  }

  // Builds the avatar for a room (either an image or a colored circle with initials)
  Widget _buildAvatar(types.Room room) {
    var color = Colors.transparent;
    if (room.type == types.RoomType.direct) {
      try {
        // Get the other user in a direct chat room
        final otherUser = room.users.firstWhere((u) => u.id != _user?.uid);
        color = getUserAvatarNameColor(
            otherUser); // Get a color based on the user's name
      } catch (e) {
        // Do nothing if the other user is not found
      }
    }
    final hasImage = room.imageUrl != null; // Check if the room has an image
    final name =
        room.name ?? ''; // Get the room name or default to an empty string

    return CircleAvatar(
      backgroundColor:
          hasImage ? Colors.transparent : color, // Set background color
      backgroundImage: hasImage
          ? NetworkImage(room.imageUrl ?? "")
          : null, // Set image if available
      radius: 28,
      child: !hasImage
          ? Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show an error message if Firebase initialization failed
    if (_error) return const Center(child: Text('An error occurred'));
    // Show a loading indicator if Firebase is not yet initialized
    if (!_initialized) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatly Plus'), // App bar title
        automaticallyImplyLeading:
            _user == null ? false : true, // Hide back button if not logged in
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // Drawer header with user information
            UserAccountsDrawerHeader(
              accountName: Text(_user?.displayName ?? 'Guest'),
              accountEmail: Text(_user?.email ?? 'Not logged in'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Text(
                  _user?.displayName ?? "", // Display user's initials
                  style: const TextStyle(fontSize: 24, color: Colors.white),
                ),
              ),
            ),
            // Navigation item to open the UsersPage
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users'),
              onTap: _user == null
                  ? null // Disable the button if not logged in
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (context) => const UsersPage(),
                        ),
                      ),
            ),
            // Navigation item to log out
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _user == null
                  ? null
                  : logout, // Disable the button if not logged in
            ),
          ],
        ),
      ),
      body: _user == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Not authenticated'), // Show message if not logged in
                  const SizedBox(height: 16),
                  // Button to navigate to the LoginPage
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => const LoginPage(),
                      ),
                    ),
                    child: const Text('Login'),
                  ),
                ],
              ),
            )
          : StreamBuilder<List<types.Room>>(
              stream: ChatlyChatCore.instance.rooms(), // Stream of chat rooms
              initialData: const [],
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No rooms available'));
                }

                // Build a list of chat rooms
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final room = snapshot.data![index];
                    return ListTile(
                      leading: _buildAvatar(room), // Display the room avatar
                      title: Text(
                        room.name ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      subtitle: FutureBuilder(
                        future: ChatlyChatCore.instance.getLastMessage(room.id),
                        builder: (context, lastMsgSnap) {
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMsgSnap.data ?? "No messages yet",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatTimeAgo(room.updatedAt ?? 0),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      onTap: () {
                        // Navigate to the ChatPage when a room is tapped
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChatPage(room: room),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  // Formats a timestamp into a human-readable time ago string
  String formatTimeAgo(int timestamp) {
    return timeago.format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }
}
