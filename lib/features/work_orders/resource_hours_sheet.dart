import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import 'work_order_models.dart';
import 'work_order_repository.dart';

String _todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

Future<bool?> showAssignmentHoursSheet(
  BuildContext context,
  WidgetRef ref, {
  required int workOrderId,
  required WorkOrderAssignment assignment,
  required bool editable,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AssignmentHoursSheet(
      workOrderId: workOrderId,
      assignment: assignment,
      editable: editable,
    ),
  );
}

Future<bool?> showQuickLogSheet(
  BuildContext context,
  WidgetRef ref, {
  required int workOrderId,
  required int zaposlenikId,
  required String zaposlenikName,
  WorkOrderAssignment? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AssignmentHoursSheet(
      workOrderId: workOrderId,
      assignment: existing ??
          WorkOrderAssignment(
            id: 0,
            zaposlenikId: zaposlenikId,
            zaposlenikName: zaposlenikName,
            datum: _todayIso(),
          ),
      editable: true,
      isQuickLog: true,
    ),
  );
}

Future<bool?> showVehicleHoursSheet(
  BuildContext context,
  WidgetRef ref, {
  required int workOrderId,
  required WorkOrderVehicle vehicle,
  required bool editable,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _VehicleHoursSheet(
      workOrderId: workOrderId,
      vehicle: vehicle,
      editable: editable,
    ),
  );
}

Future<bool?> showAddVehicleSheet(
  BuildContext context,
  WidgetRef ref, {
  required int workOrderId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AddVehicleSheet(workOrderId: workOrderId),
  );
}

class _AssignmentHoursSheet extends ConsumerStatefulWidget {
  const _AssignmentHoursSheet({
    required this.workOrderId,
    required this.assignment,
    required this.editable,
    this.isQuickLog = false,
  });

  final int workOrderId;
  final WorkOrderAssignment assignment;
  final bool editable;
  final bool isQuickLog;

  @override
  ConsumerState<_AssignmentHoursSheet> createState() =>
      _AssignmentHoursSheetState();
}

class _AssignmentHoursSheetState extends ConsumerState<_AssignmentHoursSheet> {
  late DateTime _date;
  late TextEditingController _hoursController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = _parseDate(widget.assignment.datum) ?? DateTime.now();
    _hoursController = TextEditingController(
      text: widget.assignment.sati > 0
          ? widget.assignment.sati.toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickDate() async {
    if (!widget.editable) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final sati = double.tryParse(_hoursController.text.replaceAll(',', '.'));
    if (sati == null || sati <= 0) {
      _showError('Unesite broj sati veći od 0.');
      return;
    }
    if (sati > 24) {
      _showError('Maksimalno 24 sata po zapisu.');
      return;
    }

    final zaposlenikId = widget.assignment.zaposlenikId;
    if (zaposlenikId == null) {
      _showError('Nedostaje ID djelatnika.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(workOrderRepositoryProvider);
      final datum = _formatDate(_date);
      if (widget.assignment.id > 0) {
        await repo.updateAssignment(
          id: widget.assignment.id,
          datum: datum,
          sati: sati,
        );
      } else {
        await repo.createAssignment(
          workOrderId: widget.workOrderId,
          zaposlenikId: zaposlenikId,
          datum: datum,
          sati: sati,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _showError(ApiClient.describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.isQuickLog
        ? 'Unesi moje sate'
        : widget.assignment.zaposlenikName;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (widget.assignment.pozicijaName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.assignment.pozicijaName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Datum'),
            subtitle: Text(DateFormat('dd.MM.yyyy.').format(_date)),
            trailing: widget.editable
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: widget.editable ? _pickDate : null,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hoursController,
            enabled: widget.editable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Sati',
              suffixText: 'h',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.editable)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Spremi'),
            )
          else
            Text(
              'Uređivanje nije dostupno.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _VehicleHoursSheet extends ConsumerStatefulWidget {
  const _VehicleHoursSheet({
    required this.workOrderId,
    required this.vehicle,
    required this.editable,
  });

  final int workOrderId;
  final WorkOrderVehicle vehicle;
  final bool editable;

  @override
  ConsumerState<_VehicleHoursSheet> createState() => _VehicleHoursSheetState();
}

class _VehicleHoursSheetState extends ConsumerState<_VehicleHoursSheet> {
  late DateTime _date;
  late TextEditingController _hoursController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.tryParse(widget.vehicle.datum ?? '') ?? DateTime.now();
    _hoursController = TextEditingController(
      text: widget.vehicle.sati > 0
          ? widget.vehicle.sati.toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (!widget.editable) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final sati = double.tryParse(_hoursController.text.replaceAll(',', '.'));
    if (sati == null || sati <= 0) {
      _showError('Unesite broj sati veći od 0.');
      return;
    }
    if (sati > 24) {
      _showError('Maksimalno 24 sata po zapisu.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(workOrderRepositoryProvider).updateVehicle(
            id: widget.vehicle.id,
            datum: DateFormat('yyyy-MM-dd').format(_date),
            sati: sati,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _showError(ApiClient.describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.vehicle.voziloLabel,
              style: Theme.of(context).textTheme.titleLarge),
          if (widget.vehicle.registracija.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.vehicle.registracija,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Datum'),
            subtitle: Text(DateFormat('dd.MM.yyyy.').format(_date)),
            trailing: widget.editable
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: widget.editable ? _pickDate : null,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hoursController,
            enabled: widget.editable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Sati',
              suffixText: 'h',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.editable)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Spremi'),
            )
          else
            Text(
              'Uređivanje nije dostupno.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _AddVehicleSheet extends ConsumerStatefulWidget {
  const _AddVehicleSheet({required this.workOrderId});

  final int workOrderId;

  @override
  ConsumerState<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends ConsumerState<_AddVehicleSheet> {
  List<VehicleLookup> _vehicles = [];
  VehicleLookup? _selected;
  DateTime _date = DateTime.now();
  late TextEditingController _hoursController;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController();
    _loadVehicles();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final list = await ref.read(workOrderRepositoryProvider).fetchVehicles();
      if (mounted) {
        setState(() {
          _vehicles = list;
          _loading = false;
          if (list.length == 1) _selected = list.first;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = ApiClient.describeError(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_selected == null) {
      _showError('Odaberite vozilo.');
      return;
    }
    final sati = double.tryParse(_hoursController.text.replaceAll(',', '.'));
    if (sati == null || sati <= 0) {
      _showError('Unesite broj sati veći od 0.');
      return;
    }
    if (sati > 24) {
      _showError('Maksimalno 24 sata po zapisu.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(workOrderRepositoryProvider).createVehicle(
            workOrderId: widget.workOrderId,
            voziloId: _selected!.id,
            datum: DateFormat('yyyy-MM-dd').format(_date),
            sati: sati,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _showError(ApiClient.describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Dodaj vozilo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Text(_loadError!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (_vehicles.isEmpty)
            const Text('Nema dostupnih vozila.')
          else ...[
            DropdownButton<VehicleLookup>(
              isExpanded: true,
              value: _selected,
              hint: const Text('Odaberite vozilo'),
              items: _vehicles
                  .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
                  .toList(),
              onChanged: (v) => setState(() => _selected = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Datum'),
              subtitle: Text(DateFormat('dd.MM.yyyy.').format(_date)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Sati',
                suffixText: 'h',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Dodaj'),
            ),
          ],
        ],
      ),
    );
  }
}
