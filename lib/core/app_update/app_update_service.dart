import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme_controller.dart';
import 'app_update_models.dart';
import 'app_update_repository.dart';
import 'version_utils.dart';

const _dismissedVersionKey = 'app_update_dismissed_version';

class AppUpdateService {
  AppUpdateService(this._repo, this._prefs);

  final AppUpdateRepository _repo;
  final SharedPreferences _prefs;

  Future<void> checkAndPrompt(BuildContext context) async {
    if (!context.mounted) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final config = await _repo.fetchConfig();
      if (!context.mounted) return;

      final action = _resolveAction(
        currentVersion: packageInfo.version,
        config: config,
      );
      if (action == AppUpdateAction.none) return;

      if (action == AppUpdateAction.required) {
        await _showUpdateDialog(
          context: context,
          config: config,
          required: true,
        );
        return;
      }

      if (_prefs.getString(_dismissedVersionKey) == config.latestVersion) {
        return;
      }

      await _showUpdateDialog(
        context: context,
        config: config,
        required: false,
      );
    } catch (_) {
      // Ne blokiraj app ako provjera verzije ne uspije.
    }
  }

  AppUpdateAction _resolveAction({
    required String currentVersion,
    required AppUpdateConfig config,
  }) {
    if (isVersionOlder(currentVersion, config.minVersion)) {
      return AppUpdateAction.required;
    }
    if (config.forceUpdate &&
        isVersionOlder(currentVersion, config.latestVersion)) {
      return AppUpdateAction.required;
    }
    if (isVersionOlder(currentVersion, config.latestVersion)) {
      return AppUpdateAction.optional;
    }
    return AppUpdateAction.none;
  }

  Future<void> _showUpdateDialog({
    required BuildContext context,
    required AppUpdateConfig config,
    required bool required,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !required,
      builder: (ctx) => PopScope(
        canPop: !required,
        child: AlertDialog(
          title: Text(required ? 'Potrebno ažuriranje' : 'Nova verzija'),
          content: Text(config.message),
          actions: [
            if (!required)
              TextButton(
                onPressed: () {
                  _prefs.setString(
                    _dismissedVersionKey,
                    config.latestVersion,
                  );
                  Navigator.of(ctx).pop();
                },
                child: const Text('Kasnije'),
              ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _startUpdate(config, required: required);
              },
              child: const Text('Ažuriraj'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startUpdate(
    AppUpdateConfig config, {
    required bool required,
  }) async {
    if (Platform.isAndroid) {
      final handled = await _tryPlayInAppUpdate(required: required);
      if (handled) return;
    }
    await _openStore(config.storeUrl);
  }

  Future<bool> _tryPlayInAppUpdate({required bool required}) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      if (required && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        return true;
      }
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<void> _openStore(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(
    ref.watch(appUpdateRepositoryProvider),
    ref.watch(sharedPreferencesProvider),
  );
});
