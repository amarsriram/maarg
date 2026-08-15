import 'lib/core/utils/load_formatters.dart';

void main() {
  final addrs = [
    "Electronic City, Bengaluru, Karnataka, India",
    "Sector 62, Noida, Gautam Buddha Nagar, Uttar Pradesh, India",
    "Visakhapatnam"
  ];
  
  for (var a in addrs) {
    final parsed = LoadFormatters.parseLocation(a);
    print('"$a"');
    print('  -> City: ${parsed.city}');
    print('  -> State: ${parsed.state}');
    print('  -> Code: ${parsed.stateCode}');
  }
}
