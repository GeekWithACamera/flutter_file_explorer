import 'package:flutter/material.dart';
import 'file_explorer_page.dart'; // Import the File Explorer page

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Ensure debug banner is hidden
      title: 'Flutter File Explorer',
      theme: ThemeData(
        // This is the theme of your application.
        primarySwatch: Colors.deepPurple, // Set the primary color for the app
        // Use a seed color for the color scheme
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const FileExplorerPage(), // Set FileExplorerPage as the home screen
    );
  }
}
