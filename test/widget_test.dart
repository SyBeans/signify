// Signify smoke test — verifies the app builds without crashing.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:signify/main.dart';
import 'package:signify/providers/app_state.dart';

void main() {
  testWidgets('Signify app builds and shows home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const SignifyApp(),
      ),
    );

    // Home screen should render the SIGNIFY header
    expect(find.text('SIGNIFY'), findsOneWidget);

    // Hero card text
    expect(find.text('Start Translation'), findsOneWidget);

    // Quick action tiles
    expect(find.text('Emergency'), findsWidgets); // nav bar + tile
    expect(find.text('Phrasebook'), findsWidgets);
    expect(find.text('History'), findsWidgets);
  });
}
