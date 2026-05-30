import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme_controller.dart';
import 'project_models.dart';
import 'project_repository.dart';

/// Odabrani projekt (obavezno kad postoji barem jedan aktivni).
class SelectedProjectController extends StateNotifier<int?> {
  SelectedProjectController(this._prefs) : super(null);

  final SharedPreferences _prefs;
  static const _prefsKey = 'selected_project_id';

  int? _readSavedId() {
    final saved = _prefs.getInt(_prefsKey);
    return saved;
  }

  /// Inicijalizira odabir iz liste aktivnih projekata i prefs.
  void syncFromActiveList(List<FieldworkProject> projects) {
    if (projects.isEmpty) {
      if (state != null) state = null;
      return;
    }

    final saved = _readSavedId();
    if (saved != null && projects.any((p) => p.id == saved)) {
      if (state != saved) state = saved;
      return;
    }

    final next = projects.first.id;
    if (state != next) {
      state = next;
      _prefs.setInt(_prefsKey, next);
    }
  }

  Future<void> setProject(int id) async {
    state = id;
    await _prefs.setInt(_prefsKey, id);
  }
}

final selectedProjectIdProvider =
    StateNotifierProvider<SelectedProjectController, int?>((ref) {
  final controller = SelectedProjectController(ref.watch(sharedPreferencesProvider));

  ref.listen(activeProjectsProvider, (previous, next) {
    next.whenData(controller.syncFromActiveList);
  });

  final current = ref.read(activeProjectsProvider);
  current.whenData(controller.syncFromActiveList);

  return controller;
});

final selectedProjectProvider = Provider<FieldworkProject?>((ref) {
  final id = ref.watch(selectedProjectIdProvider);
  if (id == null) return null;
  final projects = ref.watch(activeProjectsProvider).valueOrNull;
  if (projects == null) return null;
  for (final p in projects) {
    if (p.id == id) return p;
  }
  return null;
});
