// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udm_application/main.dart'; // ajuste le nom du package si nécessaire

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // On lance l'application
    await tester.pumpWidget(const UDMApp());

    // On vérifie qu'on voit bien l'écran de connexion (par exemple le texte "Université des Mascareignes")
    expect(find.text('Université des Mascareignes'), findsOneWidget);
  });
}