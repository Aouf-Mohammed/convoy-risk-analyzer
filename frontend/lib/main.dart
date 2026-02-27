import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/homescreen.dart';

void main() {
  runApp(ProviderScope(child: const ConvoyApp()));
}

class ConvoyApp extends StatelessWidget {
  const ConvoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Convoy Risk Analyzer', // our app name
      debugShowCheckedModeBanner: false, // true or false for a defence app?
      theme: ThemeData(
        brightness: Brightness.dark, // dark or light?
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(), // our first screen
    );
  }
}
