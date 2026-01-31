import 'dart:io';

import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // Added
import '../models/message.dart';
import '../services/chat_parser.dart';
import '../widgets/chat_bubble.dart';

import '../main.dart'; // Import to access themeNotifier

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Replaced ScrollController with ItemScrollController
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Configuration
  String _myName = "You"; // Default name for "Me"

  // Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchResults = []; // Indices of matching messages
  int _currentMatchIndex = -1; // Index in _searchResults

  @override
  void initState() {
    super.initState();
    _loadDefaultChat();
  }

  Future<void> _loadDefaultChat() async {
    try {
      final String content = await rootBundle.loadString('assets/chat.txt');
      if (!mounted) return;
      _parseAndLoad(content);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Could not load default chat: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        if (!mounted) return;
        _parseAndLoad(content);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking file: $e")));
    }
  }

  void _parseAndLoad(String content) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _clearSearch();
    });

    // Run parsing in background Isolate
    final request = ParseRequest(content, _myName);

    compute(parseInBackground, request)
        .then((messages) {
          if (!mounted) return;
          setState(() {
            _messages = messages;
            _isLoading = false;
          });

          // Scroll to bottom after frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_messages.isNotEmpty) {
              // Jump to end - safely
              // For ScrollablePositionedList, usually jumpTo(index: length-1)
              // We delay slightly to ensure layout?
              // Or just do nothing on initial load to avoid jumpiness? User expects to see latest.
              // _itemScrollController.jumpTo(index: _messages.length - 1);
            }
          });
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            _errorMessage = "Error parsing file: $e";
            _isLoading = false;
          });
        });
  }

  // --- Search Logic ---

  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    List<int> results = [];
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].message.toLowerCase().contains(lowerQuery)) {
        results.add(i);
      }
    }

    setState(() {
      _searchResults = results;
      _currentMatchIndex = results.isNotEmpty
          ? results.length - 1
          : -1; // Start at most recent
    });

    if (_currentMatchIndex != -1) {
      _scrollToMessage(_searchResults[_currentMatchIndex]);
    }
  }

  void _nextMatch() {
    if (_searchResults.isEmpty) return;
    setState(() {
      if (_currentMatchIndex < _searchResults.length - 1) {
        _currentMatchIndex++;
      } else {
        _currentMatchIndex = 0; // Wrap around
      }
    });
    _scrollToMessage(_searchResults[_currentMatchIndex]);
  }

  void _prevMatch() {
    if (_searchResults.isEmpty) return;
    setState(() {
      if (_currentMatchIndex > 0) {
        _currentMatchIndex--;
      } else {
        _currentMatchIndex = _searchResults.length - 1; // Wrap around
      }
    });
    _scrollToMessage(_searchResults[_currentMatchIndex]);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _currentMatchIndex = -1;
    });
  }

  void _scrollToMessage(int index) {
    if (index >= 0 && index < _messages.length) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1, // Near top
      );
    }
  }

  void _showConfigDialog() {
    TextEditingController controller = TextEditingController(text: _myName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configure 'My Name'"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Your Name in Chat Export",
            hintText: "e.g., Shakthi Nandan",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _myName = controller.text;
              });
              Navigator.pop(context);
              if (_messages.isNotEmpty) {
                // Trigger re-parsing of current content?
                // We don't have the raw content easily unless we stored it.
                // We'll just ask to reload.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Name updated. Please reload the chat file to apply changes cleanly.",
                    ),
                  ),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_messages.isEmpty) return;
    _itemScrollController.jumpTo(index: _messages.length - 1);
  }

  Future<void> _goToDate() async {
    if (_messages.isEmpty) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _messages.first.timestamp,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      // Find first message that matches or is after the selected date
      int targetIndex = _messages.indexWhere((m) {
        // Check if same day or after
        // Logic: if m.timestamp is on or after picked date (at 00:00:00)
        // We compare Date only.
        final mDate = DateTime(
          m.timestamp.year,
          m.timestamp.month,
          m.timestamp.day,
        );
        final pDate = DateTime(picked.year, picked.month, picked.day);
        return mDate.compareTo(pDate) >= 0;
      });

      if (targetIndex != -1) {
        _itemScrollController.jumpTo(index: targetIndex);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No messages found on or after this date."),
          ),
        );
      }
    }
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
    // We need keys for scrolling if we wanted to use ensureVisible, but let's skip for perf.

    return Scaffold(
      appBar: AppBar(
        // The color is handled by Theme now, but we can override if needed or rely on Theme.
        // If searching, show search bar
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: "Search...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _runSearch,
              )
            : const Text(
                "WhatsApp Parser",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            const Color(0xFF075E54), // Fallback to original color
        iconTheme:
            Theme.of(context).appBarTheme.iconTheme ??
            const IconThemeData(
              color: Colors.white,
            ), // Fallback to original color

        actions: [
          if (_isSearching) ...[
            // Search Navigation
            Center(
              child: Text(
                _searchResults.isEmpty
                    ? "0/0"
                    : "${_currentMatchIndex + 1}/${_searchResults.length}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: _prevMatch,
            ),
            IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down,
              ), // Down usually goes to "Later" (Newer) messages
              onPressed: _nextMatch,
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: _clearSearch),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: "Search",
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: "Open Chat File",
              onPressed: _pickFile,
            ),
            IconButton(
              icon: Icon(
                themeNotifier.value == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              tooltip: "Toggle Theme",
              onPressed: _toggleTheme,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'date':
                    _goToDate();
                    break;
                  case 'bottom':
                    _scrollToBottom();
                    break;
                  case 'name':
                    _showConfigDialog();
                    break;
                  case 'reset':
                    _loadDefaultChat();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'date', child: Text("Go to Date")),
                const PopupMenuItem(
                  value: 'bottom',
                  child: Text("Go to Bottom"),
                ),
                const PopupMenuItem(
                  value: 'name',
                  child: Text("Configure Name"),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Text("Reset to Default"),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Container(
        // Background handled by Scaffold theme or container override?
        // We defined scaffoldBackgroundColor in main.dart, so we don't strictly need a container color here
        // unless we want the specific wallpaper effect.
        // Let's use Theme.scaffoldBackgroundColor logic implicitly.
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : _messages.isEmpty
            ? const Center(child: Text("No messages found."))
            : ScrollablePositionedList.separated(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: const EdgeInsets.only(bottom: 20, top: 10),
                itemCount: _messages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 0),
                itemBuilder: (context, index) {
                  final msg = _messages[index];

                  bool isFocused =
                      _searchResults.isNotEmpty &&
                      _currentMatchIndex != -1 &&
                      _searchResults[_currentMatchIndex] == index;

                  return Container(
                    color: isFocused ? Colors.yellow.withOpacity(0.3) : null,
                    child: ChatBubble(
                      message: msg,
                      highlightText: _isSearching
                          ? _searchController.text
                          : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
