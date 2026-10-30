import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/repositories/local_history_repository.dart';
import 'data/repositories/pdf_operations_repository.dart';
import 'data/services/pdf_isolate_service.dart';
import 'data/services/temp_cache_cleanup_service.dart';
import 'ui/core/theme/wathiq_theme.dart';
import 'ui/features/workspace/view_models/wathiq_workspace_view_model.dart';
import 'ui/features/workspace/views/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final historyRepository = LocalHistoryRepository();
  final operationsRepository = PdfOperationsRepository(
    isolateService: const PdfIsolateService(),
    cacheCleanupService: const TempCacheCleanupService(),
    historyRepository: historyRepository,
  );
  final workspaceViewModel = WathiqWorkspaceViewModel(
    operationsRepository: operationsRepository,
    historyRepository: historyRepository,
  )..initializeHistory();

  runApp(WathiqPdfApp(viewModel: workspaceViewModel));
}

/// التطبيق الجذري "وثيق PDF" لمعالجة ملفات الـ PDF محلياً بالكامل على الجهاز.
class WathiqPdfApp extends StatelessWidget {
  const WathiqPdfApp({
    super.key,
    required this.viewModel,
  });

  final WathiqWorkspaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return MaterialApp(
          title: 'وثيق PDF',
          debugShowCheckedModeBanner: false,
          theme: WathiqTheme.buildLightTheme(),
          darkTheme: WathiqTheme.buildDarkTheme(),
          themeMode: viewModel.themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: HomeScreen(viewModel: viewModel),
          ),
        );
      },
    );
  }
}
