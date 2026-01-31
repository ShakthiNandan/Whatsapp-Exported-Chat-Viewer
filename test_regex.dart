import 'package:intl/intl.dart';

void main() {
  String textWithNarrowSpace = "30/11/25, 11:04\u202fpm - Test";
  String textWithNormalSpace = "30/11/25, 11:04 pm - Test";

  final RegExp reg = RegExp(
    r'^(\d{1,2}/\d{1,2}/\d{2,4}),\s*(\d{1,2}:\d{2}\s*[ap]m)\s*-\s*(.*)',
    caseSensitive: false,
  );

  testMatch(reg, textWithNarrowSpace, "Narrow Space");
  testMatch(reg, textWithNormalSpace, "Normal Space");
}

void testMatch(RegExp reg, String text, String label) {
  final match = reg.firstMatch(text);
  if (match != null) {
    print("[$label] Matched!");
    print(" D: ${match.group(1)}");
    print(" T: ${match.group(2)}");
    print(" M: ${match.group(3)}");

    // Test parsing
    String t = match.group(2)!.replaceAll('\u202f', ' ').trim();
    String d = match.group(1)!;
    String clean = "$d $t";
    try {
      DateFormat format = DateFormat("d/M/yy h:mm a");
      print(" Parsed: ${format.parse(clean)}");
    } catch (e) {
      print(" Parse Error: $e");
    }
  } else {
    print("[$label] NO MATCH for '$text'");
    // Debug what \s matches
    RegExp s = RegExp(r'\s');
    print(" Does \\s match narrow space? ${s.hasMatch('\u202f')}");
  }
}
