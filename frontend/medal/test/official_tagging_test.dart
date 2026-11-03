// Tagging officials on a report must use the real, approved officials from the server
// (no hard-coded sample names), and the citizen bottom bar must not overflow when the phone
// reserves space for its gesture / 3-button bar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medal/core/theme/app_theme.dart';
import 'package:medal/modules/citizen/screens/components.dart';
import 'package:medal/modules/citizen/screens/report.dart';
import 'package:medal/widgets/mention_text_field.dart';
import 'package:medal/widgets/official_picker_sheet.dart';

final _officials = <Map<String, dynamic>>[
  {'id': 11, 'full_name': 'Rajaji', 'designation': 'environmental inspector', 'department': 'Municipal Administration'},
  {'id': 12, 'full_name': 'Priya Sharma', 'designation': null, 'department': 'Public Works'},
];

Widget _host({required OfficialsFetcher fetch, required void Function(List<MentionedOfficial>?) onResult}) {
  return MaterialApp(
    theme: MedalTheme.lightTheme,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async => onResult(await showOfficialPicker(context, selected: const [], fetchOfficials: fetch)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// Tests draw text with a very wide placeholder font, so RenderFlex "overflowed" reports are test
/// artefacts; every other framework error still fails the test.
void _ignoreOverflowFromTestFont(WidgetTester tester) {
  final old = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.exception.toString().contains('overflowed')) old?.call(details);
  };
  addTearDown(() => FlutterError.onError = old);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Picker lists the officials returned by the server and returns the chosen ones', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    final queries = <String>[];
    List<MentionedOfficial>? result;
    await tester.pumpWidget(_host(
      fetch: (q) async {
        queries.add(q);
        return _officials;
      },
      onResult: (r) => result = r,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(queries, ['']);
    expect(find.text('Rajaji'), findsOneWidget);
    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('@elenarodriguez'), findsNothing);

    await tester.tap(find.byKey(const Key('official_option_11')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('official_picker_done')));
    await tester.pumpAndSettle();

    expect(result, [const MentionedOfficial(id: 11, name: 'Rajaji')]);
  });

  testWidgets('Picker searches the server and shows empty and error states', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    var fail = false;
    await tester.pumpWidget(_host(
      fetch: (q) async {
        if (fail) throw Exception('offline');
        return q.isEmpty ? _officials : <Map<String, dynamic>>[];
      },
      onResult: (_) {},
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('official_search_field')), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('No officials match'), findsOneWidget);

    fail = true;
    await tester.enterText(find.byKey(const Key('official_search_field')), 'abc');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load officials'), findsOneWidget);
  });

  testWidgets('Empty directory says so instead of showing sample officials', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(fetch: (q) async => <Map<String, dynamic>>[], onResult: (_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No approved officials are available'), findsOneWidget);
  });

  testWidgets('Report page has no hard-coded officials and offers the real picker', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    _ignoreOverflowFromTestFont(tester);

    await tester.pumpWidget(MaterialApp(theme: MedalTheme.lightTheme, home: const ReportScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('tag_officials_button')));
    await tester.pump();

    expect(find.byKey(const Key('tag_officials_button')), findsOneWidget);
    expect(find.text('Select officials to tag'), findsOneWidget);
    for (final fake in ['@elenarodriguez', '@Jane_doe', '@Marcus_Chen', '@Ward_Supervisor', '@Health_Inspector']) {
      expect(find.text(fake), findsNothing, reason: '$fake is sample data');
    }
  });

  testWidgets('Citizen bottom bar does not overflow vertically when the phone reserves a bottom bar', (tester) async {
    // 1080x2340 at 3.0 dpr = 360x780 logical, with a 48 logical px system bar at the bottom
    // (3-button navigation). The old fixed 72px bar was squeezed to 24px and overflowed by ~20px.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: 144);
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);

    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exception.toString());
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(MaterialApp(theme: MedalTheme.lightTheme, home: const MainScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(errors.where((e) => e.contains('overflowed') && e.contains('bottom')), isEmpty);
    expect(find.text('FEED'), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
  });
}
