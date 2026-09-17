import 'package:flutter_test/flutter_test.dart';
import 'package:fishlink_mobile/main.dart';

void main() {
  testWidgets('login validates required fields', (tester) async {
    await tester.pumpWidget(const FishLinkApp());
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Minimum 6 characters'), findsOneWidget);
  });
}
