import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../providers.dart';
import '../../sync/sync_engine.dart';
import '../account/account_screen.dart';
import '../agenda/agenda_screen.dart';
import '../auth/auth_session_store.dart';
import '../courses/courses_screen.dart';
import '../record/record_screen.dart';
import '../study/study_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 1;
  final _tabNavigatorKeys = List.generate(
    5,
    (_) => GlobalKey<BuddyTabNavigatorState>(),
  );
  final _tabCanPop = List.filled(5, false);

  static const _screens = [
    StudyScreen(),
    AgendaScreen(),
    RecordScreen(),
    CoursesScreen(),
    AccountScreen(),
  ];

  static const _titles = [
    'Accueil',
    'Mon agenda',
    'Enregistrer',
    'Mes cours',
    'Profil',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start a sync pass on launch.
    Future.microtask(() => ref.read(syncEngineProvider).sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncAfterResume());
    }
  }

  Future<void> _syncAfterResume() async {
    // A background worker may have rotated the refresh token while the UI
    // isolate was suspended. Reload it before the foreground sync starts.
    await AuthSessionStore.restore(ref.read(apiClientProvider));
    await ref.read(syncEngineProvider).sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(agendaReminderCoordinatorProvider);
    final phase = ref.watch(syncPhaseProvider).value ?? SyncPhase.idle;

    return Scaffold(
      appBar: _tabCanPop[_index]
          ? null
          : AppBar(
              title: Text(_titles[_index]),
              actions: [
                _SyncBadge(phase: phase, withLabel: _index == 1),
                IconButton(
                  tooltip: 'Synchroniser maintenant',
                  icon: const Icon(Icons.sync),
                  onPressed: () =>
                      ref.read(syncEngineProvider).sync(force: true),
                ),
              ],
            ),
      body: IndexedStack(
        index: _index,
        children: [
          for (var tab = 0; tab < _screens.length; tab++)
            BuddyTabNavigator(
              key: _tabNavigatorKeys[tab],
              active: tab == _index,
              root: _screens[tab],
              onCanPopChanged: (canPop) {
                if (!mounted || _tabCanPop[tab] == canPop) return;
                setState(() => _tabCanPop[tab] = canPop);
              },
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectDestination,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: _RecordNavIcon(),
            selectedIcon: _RecordNavIcon(selected: true),
            label: 'Enregistrer',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Cours',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  void _selectDestination(int destination) {
    if (destination == _index) {
      _tabNavigatorKeys[destination].currentState?.popToRoot();
      return;
    }
    setState(() => _index = destination);
  }
}

/// Keeps each primary destination's route history below the persistent menu.
/// Pages pushed from a tab use this nested navigator automatically, so their
/// AppBars retain native toolbar and Android back behavior.
class BuddyTabNavigator extends StatefulWidget {
  const BuddyTabNavigator({
    super.key,
    required this.root,
    required this.active,
    required this.onCanPopChanged,
  });

  final Widget root;
  final bool active;
  final ValueChanged<bool> onCanPopChanged;

  @override
  State<BuddyTabNavigator> createState() => BuddyTabNavigatorState();
}

class BuddyTabNavigatorState extends State<BuddyTabNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _observer = _TabStackObserver(_notifyCanPop);

  void popToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _notifyCanPop(bool canPop) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCanPopChanged(canPop);
    });
  }

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler<Object?>(
      enabled: widget.active,
      onPopWithResult: (_) => _navigatorKey.currentState?.pop(),
      child: Navigator(
        key: _navigatorKey,
        observers: [_observer],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/'),
          builder: (_) => widget.root,
        ),
      ),
    );
  }
}

class _TabStackObserver extends NavigatorObserver {
  _TabStackObserver(this.onCanPopChanged);

  final ValueChanged<bool> onCanPopChanged;
  int _routeCount = 0;

  void _notify() => onCanPopChanged(_routeCount > 1);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeCount++;
    _notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routeCount > 0) _routeCount--;
    _notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routeCount > 0) _routeCount--;
    _notify();
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.phase, required this.withLabel});
  final SyncPhase phase;
  final bool withLabel;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tooltip) = switch (phase) {
      SyncPhase.offline => (
        Icons.wifi_off,
        context.statusColors.warning,
        'Hors ligne',
      ),
      SyncPhase.pushing || SyncPhase.pulling => (
        Icons.sync,
        AppColors.secondary,
        'Synchronisation…',
      ),
      SyncPhase.error => (
        Icons.error_outline,
        AppColors.error,
        'Erreur de synchronisation',
      ),
      _ => (Icons.cloud_done, context.statusColors.success, 'Synchronisé'),
    };
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 19),
            if (withLabel) ...[
              const SizedBox(width: 5),
              Text(
                tooltip,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordNavIcon extends StatelessWidget {
  const _RecordNavIcon({this.selected = false});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: selected ? 48 : 44,
      height: selected ? 48 : 44,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
    );
  }
}
