import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:amaranto_feed/services/release_update_service.dart';
import 'package:amaranto_feed/theme/app_theme.dart';
import 'package:amaranto_feed/widgets/release_update_button.dart';

import 'release_update_service_test.dart' show release;

void main() {
  testWidgets('a newer APK shows the button and opens its download on tap', (
    tester,
  ) async {
    Uri? opened;
    final service = ReleaseUpdateService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(release('1.0.1')), 200),
      ),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ReleaseUpdateButton(
            service: service,
            versionLoader: () async => '1.0.0',
            openDownload: (url) async {
              opened = url;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Scarica aggiornamento 1.0.1'), findsOneWidget);
    expect(opened, isNull);
    await tester.tap(find.byIcon(Icons.system_update_rounded));
    await tester.pumpAndSettle();
    expect(
      opened.toString(),
      contains('/releases/download/v1.0.1/amaranto-feed-1.0.1.apk'),
    );
  });

  testWidgets('current version hides the button', (tester) async {
    final service = ReleaseUpdateService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(release('1.0.0')), 200),
      ),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReleaseUpdateButton(
            service: service,
            versionLoader: () async => '1.0.0',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.system_update_rounded), findsNothing);
  });

  testWidgets('a failed browser launch gives a retry message', (tester) async {
    final service = ReleaseUpdateService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(release('1.0.1')), 200),
      ),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReleaseUpdateButton(
            service: service,
            versionLoader: () async => '1.0.0',
            openDownload: (_) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.system_update_rounded));
    await tester.pumpAndSettle();
    expect(
      find.text('Impossibile avviare il download. Riprova.'),
      findsOneWidget,
    );
  });
}
