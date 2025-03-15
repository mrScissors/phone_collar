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
      theme: ThemeData(primarySwatch: Colors.orange),
      home: HomeScreen(localDbService: localDbService),
    );
  }
}
