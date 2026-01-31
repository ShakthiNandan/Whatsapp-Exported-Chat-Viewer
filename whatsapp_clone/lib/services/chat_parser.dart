import 'package:intl/intl.dart';
import '../models/message.dart';

class ParseRequest {
  final String content;
  final String myName;

  ParseRequest(this.content, this.myName);
}

// Top-level function for compute
List<ChatMessage> parseInBackground(ParseRequest request) {
  return ChatParser.parse(request.content, myName: request.myName);
}

class ChatParser {
  // Regex to identify the start of a message: "11/12/25, 3:14 pm - "
  // Handles 2 or 4 digit years.
  static final RegExp _headerRegex = RegExp(
    r'^(\d{1,2}/\d{1,2}/\d{2,4}),\s*(\d{1,2}:\d{2}\s*[ap]m)\s*-\s*(.*)',
    caseSensitive: false,
  );

  /// Parses the raw text content of a WhatsApp export file.
  /// [content] is the full text of the file.
  /// [myName] is the name used to identify the current user (for "isMe").
  /// Usually "You" in English exports, but might be the user's name if they exported it?
  /// Actually, in exports, your messages usually appear as "You" or your saved name.
  /// We'll let the user configure it, defaulting to "You".
  static List<ChatMessage> parse(String content, {String myName = "You"}) {
    List<ChatMessage> messages = [];
    List<String> lines = content.split('\n');

    ChatMessage? currentMessage;

    // Format: 11/12/25, 3:14 pm
    // DateFormat patterns:
    // d/M/yy matches 11/12/25
    // h:mm at matches 3:14 pm (using specific pattern logic)

    for (var line in lines) {
      line = line.trimRight(); // Keep separate lines but remove trailing \r
      if (line.isEmpty) continue;

      final match = _headerRegex.firstMatch(line);

      if (match != null) {
        // It's a new message
        if (currentMessage != null) {
          messages.add(currentMessage);
        }

        String dateStr = match.group(1)!;
        String timeStr = match.group(2)!; // e.g., "3:14 pm"
        String remainder = match.group(
          3,
        )!; // "Ambika Mam Tekmedia: Ok..." or "System msg"

        // Parse DateTime
        DateTime? dt = _parseDateTime(dateStr, timeStr);
        if (dt == null) {
          // Fallback or error handling? Just skip for now or treat as text?
          // If we can't parse date, maybe it's not a valid header.
          // But regex matched. Let's try our best.
          dt = DateTime.now(); // Placeholder
        }

        // Check for Sender
        // logic: look for first ": "
        int colIndex = remainder.indexOf(': ');
        String? sender;
        String msgContent;
        bool isMe = false;

        if (colIndex != -1) {
          // Has sender
          sender = remainder.substring(0, colIndex);
          msgContent = remainder.substring(colIndex + 2);

          if (sender == myName || sender == "You") {
            // "You" is common in exports
            isMe = true;
          }
        } else {
          // System message
          sender = null;
          msgContent = remainder;
          isMe = false;
        }

        // Handle specific case where "You" might be the name provided
        if (sender != null && sender.toLowerCase() == myName.toLowerCase()) {
          isMe = true;
        }

        currentMessage = ChatMessage(
          timestamp: dt,
          sender: sender,
          message: msgContent,
          isMe: isMe,
        );
      } else {
        // Continuation of previous message
        if (currentMessage != null) {
          // Create a new instance with appended text because generic classes are immutable usually,
          // but efficiently we can just accumulate strings before creating object.
          // Since I defined ChatMessage as immutable, I'll cheat a bit by creating a new one
          // or use a builder. For simplicity here:
          currentMessage = ChatMessage(
            timestamp: currentMessage.timestamp,
            sender: currentMessage.sender,
            message: "${currentMessage.message}\n$line",
            isMe: currentMessage.isMe,
          );
        }
      }
    }

    if (currentMessage != null) {
      messages.add(currentMessage);
    }

    return messages;
  }

  static DateTime? _parseDateTime(String datePart, String timePart) {
    try {
      // Clean up whitespace
      datePart = datePart.trim();
      // Handle narrow non-breaking space (U+202F) and normal non-breaking space (U+00A0)
      timePart = timePart
          .replaceAll('\u202f', ' ')
          .replaceAll('\u00a0', ' ')
          .trim();

      // DateFormat expects uppercase AM/PM
      timePart = timePart.toUpperCase();

      // Normalize date: 1/1/25 -> 01/01/2025 logic handled by DateFormat mostly,
      // but ensure year format.

      String combined = "$datePart $timePart";
      // Expected: "11/12/25 3:14 PM"

      DateFormat format = DateFormat("d/M/yy h:mm a");
      return format.parse(combined);
    } catch (e) {
      // debugPrint("Error parsing date: $datePart $timePart -> $e");
      return null;
    }
  }
}
