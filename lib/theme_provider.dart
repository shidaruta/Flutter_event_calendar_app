import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkTheme = false;

  bool get isDarkTheme => _isDarkTheme;

  void toggleTheme() {
    _isDarkTheme = !_isDarkTheme;
    notifyListeners();
  }

  ThemeData get themeData {
    return _isDarkTheme
        ? ThemeData.dark().copyWith(
      colorScheme:  const ColorScheme.dark().copyWith(primary: Colors.blueAccent),
      appBarTheme:  const AppBarTheme(
        backgroundColor: Colors.blueAccent,
      ),

    )
        : ThemeData.light().copyWith(
      colorScheme:  const ColorScheme.light().copyWith(primary: Colors.lightBlue),
      appBarTheme:  const AppBarTheme(
        backgroundColor: Colors.lightBlue,
      ),
    );
  }
}
