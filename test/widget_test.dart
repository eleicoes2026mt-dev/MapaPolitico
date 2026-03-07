// Teste básico do app CampanhaMT

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:campanha_mt/core/router/app_router.dart';
import 'package:campanha_mt/main.dart';

void main() {
  testWidgets('App inicia e exibe título', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-key',
    );
    final router = createAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        child: CampanhaMTApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CampanhaMT'), findsWidgets);
  });
}
