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
                final name = p
                    .basenameWithoutExtension(path)
                    .replaceAll("WhatsApp Chat with ", "");

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
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF075E54),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      name,
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
