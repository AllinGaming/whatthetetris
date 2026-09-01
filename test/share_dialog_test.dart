import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatthetetris/ui/widgets/share_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('share dialog is email-free and copies the public game link', (
    WidgetTester tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTriangleShareDialog(
                context,
                title: 'Share your result',
                message: 'I scored 100 points!',
              ),
              child: const Text('Open share'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();

    expect(find.text('Copy game link'), findsOneWidget);
    expect(find.text('Share on X'), findsOneWidget);
    expect(find.text('Share on Facebook'), findsOneWidget);
    expect(find.text('Share on WhatsApp'), findsOneWidget);
    expect(find.textContaining('Email'), findsNothing);

    await tester.tap(find.text('Copy game link'));
    await tester.pumpAndSettle();

    expect(copiedText, triangleGameUrl);
    expect(find.text('Share your result'), findsNothing);
  });

  testWidgets('room sharing copies the code and game link together', (
    WidgetTester tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    const invite = 'Join my What The Triangle 2 Player room: ABC234';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTriangleShareDialog(
                context,
                title: 'Share room ABC234',
                message: invite,
                copyLabel: 'Copy invite',
                copyText: '$invite\n$triangleGameUrl',
              ),
              child: const Text('Share room'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Share room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy invite'));
    await tester.pumpAndSettle();

    expect(copiedText, contains('ABC234'));
    expect(copiedText, contains(triangleGameUrl));
  });
}
