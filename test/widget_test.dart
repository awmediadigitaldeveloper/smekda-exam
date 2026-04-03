import 'package:flutter_test/flutter_test.dart';
import 'package:smekda_mobile_test/main.dart';

void main() {
  test('app URL stays on HTTPS', () {
    expect(appHomeUrl.scheme, 'https');
    expect(appHomeUrl.host, 'smekda-mobile-test.vercel.app');
  });
}
