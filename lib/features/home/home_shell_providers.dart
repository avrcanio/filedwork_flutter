import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aktivni tab u HomeShell (0 = Nalozi, 1 = Izvještaj, 2 = Postavke).
final homeShellTabProvider = StateProvider<int>((ref) => 0);
