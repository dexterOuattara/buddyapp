import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../sync/sync_engine.dart';
import '../account/account_screen.dart';
import '../agenda/agenda_screen.dart';
import '../courses/courses_screen.dart';
import '../record/record_screen.dart';
import '../study/study_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _screens = [
    AgendaScreen(),
    CoursesScreen(),
    RecordScreen(),
    StudyScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Start a sync pass on launch.
    Future.microtask(() => ref.read(syncEngineProvider).sync());
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(syncPhaseProvider).value ?? SyncPhase.idle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BuddyWize'),
        actions: [
          _SyncBadge(phase: phase),
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(syncEngineProvider).sync(),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Record'),
          NavigationDestination(icon: Icon(Icons.auto_stories), label: 'Study'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.phase});
  final SyncPhase phase;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tooltip) = switch (phase) {
      SyncPhase.offline => (Icons.wifi_off, Colors.orange, 'Offline'),
      SyncPhase.pushing || SyncPhase.pulling => (Icons.sync, Colors.blue, 'Syncing'),
      SyncPhase.error => (Icons.error_outline, Colors.red, 'Sync error'),
      _ => (Icons.cloud_done, Colors.green, 'Up to date'),
    };
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
