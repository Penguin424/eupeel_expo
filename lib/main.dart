import 'package:eupeel_expo/src/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:toastification/toastification.dart';

void main() {
  return runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalLoaderOverlay(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme:
              ThemeData(
                colorScheme: ColorScheme(
                  primary: const Color(0xFF4CAAB1),
                  onPrimary: Colors.white,
                  surface: const Color(0xFFBFE3ED),
                  secondary: const Color(0xFF36787D),
                  onSecondary: Colors.white,
                  error: Colors.red,
                  onError: Colors.red,
                  onSurface: Colors.black,
                  brightness: Brightness.light,
                ),
                textTheme: const TextTheme(
                  titleLarge: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFFE6F1F8),
                  ),
                  headlineLarge: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFFE6F1F8),
                  ),
                  bodyLarge: TextStyle(
                    fontSize: 16,
                    color: Color(0XFFE6F1F8),
                  ),
                  bodyMedium: TextStyle(
                    fontSize: 14,
                    color: Color(0XFFE6F1F8),
                  ),
                ),
              ).copyWith(
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF4CAAB1),
                  centerTitle: true,
                  titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF4CAAB1),
                    overlayColor: const Color(0xFF36787D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
          debugShowCheckedModeBanner: false,

          title: 'Material App',
          initialRoute: "/",
          routes: {
            "/": (context) => HomeScreen(),
          },
        ),
      ),
    );
  }
}
