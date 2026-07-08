import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import 'providers/channel_provider.dart';
import 'screens/splash_screen.dart';
import 'services/channel_service.dart'; // Importação necessária para inicialização segura
import 'utils/app_theme.dart';

/// Grava de forma segura logs de falha no armazenamento local do dispositivo
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
  // Captura erros síncronos lançados pela engine do Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    final exception = details.exceptionAsString();
    final stackTrace = details.stack.toString();
    
    debugPrint('🔴 Erro crítico do Flutter interceptado: $exception');
    _writeCrashLog('FLUTTER CRASH EXCEPTION:\n$exception\n\nSTACK TRACE:\n$stackTrace');
  };

  // Executa o aplicativo dentro de uma Zona Protegida contra falhas assíncronas (ex: requisições HTTP órfãs)
  runZonedGuarded(
    () async {
      // 1. Inicializa os canais de ligação nativos do Flutter obrigatoriamente como primeira instrução
      WidgetsFlutterBinding.ensureInitialized();
      
      // 2. Trava a orientação padrão em modo Retrato (Portrait)
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } catch (e) {
        debugPrint('⚠️ Alerta: Falha ao travar orientação do ecrã.');
      }

      // 3. Inicialização segura e centralizada de Banco de Dados local (Hive)
      try {
        debugPrint('📦 Inicializando banco de dados local (Hive)...');
        await ChannelService.initHive(); // Inicializa o Hive, registra adaptadores e abre as boxes
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
        themeMode: ThemeMode.system, // Segue o tema padrão configurado no sistema do telemóvel
        home: const SplashScreen(),
        builder: (context, child) {
          // Injeta a barreira inteligente de proteção contra falhas visuais de widgets
          return _ErrorBoundary(child: child!);
        },
      ),
    );
  }
}

/// Widget Boundary que intercepta falhas de renderização de forma dinâmica
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

    // INTERCEPTADOR ATIVO: Redireciona a tela vermelha da morte para a nossa UI customizada
    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _errorMessage = details.exceptionAsString();
        });
      }
      _writeCrashLog('RENDER ENGINE CRASH:\n${details.exceptionAsString()}\n\nSTACK:\n${details.stack}');
      
      // Retorna um widget vazio temporário para evitar loops visuais de crash
      return const SizedBox.shrink();
    };
  }

  /// Resolve o caminho absoluto do arquivo de logs de forma dinâmica para cada telemóvel
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
    // Limpa o erro se o widget for atualizado pelo sistema de hot-reload ou navegação
    setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF060E1A), // Fundo azul escuro premium do app
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  
                  // Bloco de visualização de erro técnico
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
                      backgroundColor: const Color(0xFFD32F2F), // Cor vermelha amigável
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
