// lib/main.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Importação do Hive Flutter

import 'providers/channel_provider.dart';
import 'screens/splash_screen.dart';
import 'services/channel_service.dart';
import 'utils/app_theme.dart';

/// CLASSE DE SEGURANÇA BATCH: Força o Flutter a aceitar conexões HTTP/HTTPS 
/// de painéis IPTV com certificados SSL expirados, autoassinados ou inválidos.
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> _writeCrashLog(String error) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/crash_log.txt');
    final timestamp = DateTime.now().toIso8601String();
    final content = '$timestamp\n$error\n\n=================================\n';
    
    await file.writeAsString(content, mode: FileMode.append);
    debugPrint('💾 Log de erro salvo em: ${file.path}');
  } catch (e) {
    debugPrint('❌ Falha ao tentar gravar log físico: $e');
  }
}

void main() async {
  // ATIVAÇÃO DO BYPASS SSL
  HttpOverrides.global = MyHttpOverrides();

  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exceptionAsString();
    final stackTrace = details.stack.toString();
    
    debugPrint('🔴 Erro crítico do Flutter interceptado: $exception');
    _writeCrashLog('FLUTTER CRASH EXCEPTION:\n$exception\n\nSTACK TRACE:\n$stackTrace');
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } catch (e) {
        debugPrint('⚠️ Alerta: Falha ao travar orientação do ecrã.');
      }

      // 3. Inicialização segura e síncrona do Hive e SharedPreferences
      try {
        debugPrint('📦 Inicializando Hive Flutter Engine...');
        await Hive.initFlutter(); // <-- LINHA CRÍTICA ADICIONADA! Inicializa o core do banco de dados
        
        debugPrint('📦 Abrindo tabelas locais...');
        await ChannelService.initHive(); // Inicializa adaptadores e abre as tabelas
        debugPrint('✅ Hive e tabelas prontas para uso.');
      } catch (e, stack) {
        debugPrint('❌ Falha catastrófica ao iniciar o Hive: $e');
        _writeCrashLog('HIVE BOOTSTRAP FAILURE:\n$e\n\nSTACK:\n$stack');
        rethrow;
      }

      debugPrint('🚀 AngoMovie inicializado com sucesso. Iniciando UI.');
      runApp(const AngoMovieApp());
    },
    (error, stack) {
      debugPrint('🔴 Erro assíncrono capturado pela zona: $error');
      _writeCrashLog('UNCAUGHT ZONE ERROR:\n$error\n\nSTACK TRACE:\n$stack');
    },
  );
}

class AngoMovieApp extends StatelessWidget {
  const AngoMovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChannelProvider()),
      ],
      child: MaterialApp(
        title: 'AngoMovie IPTV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system, 
        home: const SplashScreen(),
        builder: (context, child) {
          return _ErrorBoundary(child: child!);
        },
      ),
    );
  }
}

class _ErrorBoundary extends StatefulWidget {
  final Widget child;

  const _ErrorBoundary({required this.child});

  @override
  State<_ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<_ErrorBoundary> {
  String? _errorMessage;
  String _dynamicLogPath = 'A calcular diretório...';

  @override
  void initState() {
    super.initState();
    _loadDynamicLogPath();

    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _errorMessage = details.exceptionAsString();
        });
      }
      _writeCrashLog('RENDER ENGINE CRASH:\n${details.exceptionAsString()}\n\nSTACK:\n${details.stack}');
      return const SizedBox.shrink();
    };
  }

  Future<void> _loadDynamicLogPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (mounted) {
        setState(() {
          _dynamicLogPath = '${dir.path}/crash_log.txt';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _dynamicLogPath = 'Armazenamento interno protegido.');
      }
    }
  }

  @override
  void didUpdateWidget(_ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF060E1A), 
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: Main => MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_outlined, color: Colors.redAccent, size: 72),
                  const SizedBox(height: 24),
                  const Text(
                    'Erro no carregamento visual',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Um componente do aplicativo falhou ao tentar ser exibido no ecrã.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _errorMessage = null),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Recarregar Interface', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Caminho físico do ficheiro de depuração:',
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _dynamicLogPath,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
