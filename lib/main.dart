import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/database/app_database.dart';
import 'data/repositories/document_repository.dart';
import 'firebase_options.dart';
import 'logic/providers/auth_provider.dart';
import 'logic/providers/cloud_document_provider.dart';
import 'logic/providers/document_provider.dart';
import 'logic/providers/theme_provider.dart';
import 'logic/services/document_service.dart';
import 'supabase_config.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase với fallback an toàn
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initializeApp note: $e');
  }

  // Khởi tạo Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialize note: $e');
  }

  // Khởi tạo Database cục bộ
  final database = AppDatabase();
  final documentRepo = DocumentRepositoryImpl();
  final documentService = DocumentService(repository: documentRepo);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<DocumentRepository>.value(value: documentRepo),
        Provider<DocumentService>.value(value: documentService),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider(database)),
        ChangeNotifierProxyProvider<AuthProvider, CloudDocumentProvider>(
          create: (_) => CloudDocumentProvider(documentService),
          update: (_, auth, cloudDocs) {
            final provider = cloudDocs ?? CloudDocumentProvider(documentService);
            provider.loadDocumentsForUser(auth.currentUser?.uid);
            return provider;
          },
        ),
      ],
      child: const StudyDocManagerApp(),
    ),
  );
}

class StudyDocManagerApp extends StatelessWidget {
  const StudyDocManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Quản Lý Tài Liệu Học Tập',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      // Thiết kế Material 3 phong cách Material You hiện đại
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5), // Xanh dương tri thức
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        cardTheme: const CardThemeData(
          clipBehavior: Clip.antiAlias,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
        cardTheme: const CardThemeData(
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
