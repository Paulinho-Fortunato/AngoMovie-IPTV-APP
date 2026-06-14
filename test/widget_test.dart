import 'package:flutter_test/flutter_test.dart';
import 'package:angomovie_iptv/main.dart';

void main() {
  testWidgets('AngoMovie IPTV app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const AngoMovieApp());
    expect(find.byType(AngoMovieApp), findsOneWidget);
  });
}
