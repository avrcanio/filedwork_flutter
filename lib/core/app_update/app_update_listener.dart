import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_update_service.dart';

final _appUpdateCheckedProvider = StateProvider<bool>((ref) => false);

/// Pokreće provjeru verzije jednom nakon prvog frame-a.
class AppUpdateListener extends ConsumerStatefulWidget {
  const AppUpdateListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateListener> createState() => _AppUpdateListenerState();
}

class _AppUpdateListenerState extends ConsumerState<AppUpdateListener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    if (ref.read(_appUpdateCheckedProvider) || !mounted) return;
    ref.read(_appUpdateCheckedProvider.notifier).state = true;
    await ref.read(appUpdateServiceProvider).checkAndPrompt(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
