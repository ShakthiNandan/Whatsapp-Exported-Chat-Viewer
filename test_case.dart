import 'package:intl/intl.dart';

void main() {
  testParse("30/11/25 11:04 PM"); // Uppercase
  testParse("30/11/25 11:04 pm"); // Lowercase
}

void testParse(String input) {
  try {
    DateFormat format = DateFormat("d/M/yy h:mm a");
    print("Input: '$input' -> Parsed: ${format.parse(input)}");
  } catch (e) {
    print("Input: '$input' -> FAILED: $e");
  }
}
