import 'package:intl/intl.dart';

void main() {
  testParse("11/12/25", "3:14 pm");
  testParse("11/12/25", "3:14 PM");
  testParse("12/12/25", "9:00 am");
}

void testParse(String d, String t) {
  String combined = "$d $t";
  try {
    DateFormat format = DateFormat("d/M/yy h:mm a");
    DateTime dt = format.parse(combined);
    print("Success: '$combined' -> $dt");
  } catch (e) {
    print("Failed: '$combined' -> $e");
  }
}
