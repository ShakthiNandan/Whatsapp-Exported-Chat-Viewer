import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String? highlightText;

  const ChatBubble({super.key, required this.message, this.highlightText});

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return _buildSystemMessage(context);
    }
    return _buildUserMessage(context);
  }

  Widget _buildSystemMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFE1F3FB),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
        child: RichText(
          textAlign: TextAlign.center,
          text: _buildHighlightedText(
            message.message,
            highlightText,
            TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF8696A0) : const Color(0xFF555555),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context) {
    final isMe = message.isMe;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Light: Me(DCF8C6), Other(White)
    // Dark: Me(005C4B), Other(1F2C34)
    final color = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
        : (isDark ? const Color(0xFF1F2C34) : Colors.white);

    final textColor = isDark ? const Color(0xFFE9EDEF) : Colors.black87;
    final timeColor = isDark ? const Color(0xFF8696A0) : Colors.grey[600];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: isMe
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    topRight: Radius.circular(0),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(0),
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 10,
                  right: 10,
                  top: 6,
                  bottom: 22, // Space for time
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && message.sender != null) ...[
                      Text(
                        message.sender!,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF64B5F6)
                              : const Color(0xFFD35400),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    RichText(
                      text: _buildHighlightedText(
                        message.message,
                        highlightText,
                        TextStyle(fontSize: 15, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 4,
                right: 8,
                child: Text(
                  DateFormat('h:mm a').format(message.timestamp).toLowerCase(),
                  style: TextStyle(fontSize: 11, color: timeColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(
    String text,
    String? query,
    TextStyle baseStyle,
  ) {
    if (query == null || query.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    // Quick check
    if (!lowerText.contains(lowerQuery)) {
      return TextSpan(text: text, style: baseStyle);
    }

    List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch = lowerText.indexOf(lowerQuery, start);

    while (indexOfMatch != -1) {
      // Add non-matched part
      if (indexOfMatch > start) {
        spans.add(
          TextSpan(text: text.substring(start, indexOfMatch), style: baseStyle),
        );
      }

      // Add matched part with highlight
      spans.add(
        TextSpan(
          text: text.substring(indexOfMatch, indexOfMatch + lowerQuery.length),
          style: baseStyle.copyWith(
            backgroundColor: Colors.yellow,
            color: Colors.black, // Ensure text is visible on yellow
          ),
        ),
      );

      start = indexOfMatch + lowerQuery.length;
      indexOfMatch = lowerText.indexOf(lowerQuery, start);
    }

    // Add remaining
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return TextSpan(children: spans);
  }
}
