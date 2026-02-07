import 'package:flutter_test/flutter_test.dart';

import 'package:camera_app/main.dart';

void main() {
  testWidgets('Shows message when no cameras are available',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CameraApp(cameras: [], initError: null));
    await tester.pump();

    expect(find.text('No cameras found on this device.'), findsOneWidget);
  });
}
