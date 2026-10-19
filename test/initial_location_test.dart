import 'package:clinic_solution/ui/navigation/initial_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native startup stays on login even with a web registration URL', () {
    expect(
      initialClinicLocation(
        web: false,
        uri: Uri.parse('https://clinic.orbyteza.com/#/register'),
      ),
      '/login',
    );
  });
  test(
    'web startup preserves registration, recovery and protected hash links',
    () {
      for (final route in [
        '/register',
        '/login',
        '/forgot',
        '/home',
        '/appointment',
        '/register?source=website',
      ]) {
        expect(
          initialClinicLocation(
            web: true,
            uri: Uri.parse('https://clinic.orbyteza.com/#$route'),
          ),
          route,
        );
      }
    },
  );
  test('direct web path and its query are preserved', () {
    expect(
      initialClinicLocation(
        web: true,
        uri: Uri.parse('https://clinic.orbyteza.com/register?source=website'),
      ),
      '/register?source=website',
    );
  });
  test('public root and public anchors use login if the app is started', () {
    for (final path in ['/', '/#features', '/index.html']) {
      expect(
        initialClinicLocation(
          web: true,
          uri: Uri.parse('https://clinic.orbyteza.com$path'),
        ),
        '/login',
      );
    }
  });
}
