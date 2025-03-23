import 'package:flutter/material.dart';
import 'screens/home/home.dart';
import 'services/local_db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the local DB service.
  final localDbService = LocalDbService();
  await localDbService.initialize();

  runApp(CallLogApp(localDbService: localDbService));
}

class CallLogApp extends StatelessWidget {
  final LocalDbService localDbService;

  const CallLogApp({Key? key, required this.localDbService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Call Log App',
      home: HomeScreen(localDbService: localDbService),
      theme: ThemeData(
        primarySwatch: Colors.orange,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange,
          onPrimary: Colors.black,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.black,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black, backgroundColor: Colors.orange,
          ),
        ),
        useMaterial3: true,
      ),
    );
  }
}
