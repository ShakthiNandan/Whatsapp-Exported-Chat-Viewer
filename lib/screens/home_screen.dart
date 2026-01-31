import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'chat_screen.dart';
import '../main.dart'; // For themeNotifier

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _chatFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedChats();
  }

  Future<void> _loadSavedChats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _chatFiles = prefs.getStringList('chat_files') ?? [];
      _isLoading = false;
    });
  }

  Future<void> _addChatFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null) {
        final path = result.files.single.path!;
        if (!_chatFiles.contains(path)) {
          final prefs = await SharedPreferences.getInstance();
          final updatedList = List<String>.from(_chatFiles)..add(path);
          await prefs.setStringList('chat_files', updatedList);

          setState(() {
            _chatFiles = updatedList;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking file: $e")));
    }
  }

  Future<void> _removeChat(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final updatedList = List<String>.from(_chatFiles)..remove(path);
    await prefs.setStringList('chat_files', updatedList);
    setState(() {
      _chatFiles = updatedList;
    });
  }

  /// Tries to extract a display name from the file content.
  /// It reads a small chunk of the file to find the first sender name.
  Future<String> _getChatName(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return p
          .basenameWithoutExtension(path)
          .replaceAll("WhatsApp Chat with ", "");
    }

    try {
      // Read first 10KB to find a name
      // We assume standard encoding (UTF-8 usually)
      final stream = file.openRead(0, 1024 * 10).transform(utf8.decoder);

      // We only need the first chunk usually
      final content = await stream.first;

      // Regex to find names: starts with date/time, then " - Name: "
      // 25/01/2026, 9:22 am - Shakthi: Message
      // Pattern: \d{1,2}/\d{1,2}/\d{2,4},?\s\d{1,2}:\d{2}\s?[aApP]?[mM]?\s?-\s([^:]+):
      final regex = RegExp(
        r'\d{1,2}\/\d{1,2}\/\d{2,4},?\s?\d{1,2}:\d{2}\s?[aApP]?[mM]?\s?-\s([^:]+):',
      );
      final matches = regex.allMatches(content);

      final Set<String> names = {};

      // Collect first few unique names
      for (final match in matches) {
        if (match.groupCount >= 1) {
          String name = match.group(1)!.trim();
          // Filter out "You" and generic system messages slightly randomly if precise check fails
          if (name.toLowerCase() != 'you' &&
              !name.contains('Messages and calls are end-to-end encrypted') &&
              !name.contains('created group') &&
              !name.contains('added you')) {
            names.add(name);
          }
        }
        if (names.length >= 2) break; // Don't need too many
      }

      if (names.isNotEmpty) {
        // Return first found name.
        // In a 1-on-1 chat, "You" and "Person" are the participants.
        // If we filtered "You", we likely have "Person".
        return names.first;
      }
    } catch (e) {
      // Fallback
    }

    return p
        .basenameWithoutExtension(path)
        .replaceAll("WhatsApp Chat with ", "");
  }

  // --- Theme Toggle ---
  void _toggleTheme() {
    final current = themeNotifier.value;
    themeNotifier.value = current == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "WhatsApp Chats",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeNotifier.value == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            tooltip: "Toggle Theme",
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatFiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No chats added yet",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addChatFile,
                    icon: const Icon(Icons.add),
                    label: const Text("Import Chat"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _chatFiles.length,
              itemBuilder: (context, index) {
                final path = _chatFiles[index];

                return Dismissible(
                  key: Key(path),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeChat(path),
                  child: FutureBuilder<String>(
                    future: _getChatName(path),
                    builder: (context, snapshot) {
                      final displayName =
                          snapshot.data ??
                          p
                              .basenameWithoutExtension(path)
                              .replaceAll("WhatsApp Chat with ", "");

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF075E54),
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : "?",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(filePath: path),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addChatFile,
        backgroundColor: const Color(0xFF25D366),
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }
}
