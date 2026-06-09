import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../shared/utils/app_dates.dart';
import '../auth/auth_models.dart';
import '../executions/execution_repository.dart';
import '../work_items/work_item_models.dart';
import 'work_order_models.dart';
import 'work_order_repository.dart';

Future<bool?> showWorkItemHoursSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<WorkItem> workItems,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _WorkItemHoursSheet(workItems: workItems),
  );
}

Future<bool?> showUnifiedHoursSheet(
  BuildContext context,
  WidgetRef ref, {
  required int workOrderId,
  required FieldworkCapabilities fieldwork,
  WorkOrderAssignment? existing,
  int? defaultZaposlenikId,
  String? defaultZaposlenikName,
  DateTime? initialDate,
  bool editable = true,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _UnifiedHoursSheet(
      workOrderId: workOrderId,
      fieldwork: fieldwork,
      assignment: existing,
      defaultZaposlenikId: defaultZaposlenikId,
      defaultZaposlenikName: defaultZaposlenikName,
      initialDate: initialDate,
      editable: editable,
    ),
  );
}

Future<bool?> showAssignmentHoursSheet(
  BuildContext context,
  WidgetRef ref, {
  required int workOrderId,
  required WorkOrderAssignment assignment,
  required FieldworkCapabilities fieldwork,
  required bool editable,
  DateTime? initialDate,
}) {
  return showUnifiedHoursSheet(
    context,
    ref,
    workOrderId: workOrderId,
    fieldwork: fieldwork,
    existing: assignment,
    initialDate: initialDate,
    editable: editable,
  );
}

Future<bool?> showQuickLogSheet(
  BuildContext context,
  WidgetRef ref, {
  required int workOrderId,
  required FieldworkCapabilities fieldwork,
  required int zaposlenikId,
  required String zaposlenikName,
  WorkOrderAssignment? existing,
  DateTime? initialDate,
}) {
  return showUnifiedHoursSheet(
    context,
    ref,
    workOrderId: workOrderId,
    fieldwork: fieldwork,
    existing: existing,
    defaultZaposlenikId: zaposlenikId,
    defaultZaposlenikName: zaposlenikName,
    initialDate: initialDate,
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

class _UnifiedHoursSheet extends ConsumerStatefulWidget {
  const _UnifiedHoursSheet({
    required this.workOrderId,
    required this.fieldwork,
    this.assignment,
    this.defaultZaposlenikId,
    this.defaultZaposlenikName,
    this.initialDate,
    this.editable = true,
  });

  final int workOrderId;
  final FieldworkCapabilities fieldwork;
  final WorkOrderAssignment? assignment;
  final int? defaultZaposlenikId;
  final String? defaultZaposlenikName;
  final DateTime? initialDate;
  final bool editable;

  @override
  ConsumerState<_UnifiedHoursSheet> createState() => _UnifiedHoursSheetState();
}

class _UnifiedHoursSheetState extends ConsumerState<_UnifiedHoursSheet> {
  List<WorkerLookup> _workers = [];
  List<VehicleLookup> _vehicles = [];
  WorkerLookup? _selectedWorker;
  VehicleLookup? _noneVehicle;
  VehicleLookup? _selectedVehicle;
  late DateTime _date;
  late TextEditingController _hoursController;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  String? _loadError;

  bool get _isEdit => widget.assignment != null && widget.assignment!.id > 0;

  @override
  void initState() {
    super.initState();
    _noneVehicle = const VehicleLookup(id: 0, label: '— Bez stroja —');
    _selectedVehicle = _noneVehicle;
    final assignment = widget.assignment;
    _date = parseApiDate(assignment?.datum) ??
        widget.initialDate ??
        DateTime.now();
    _hoursController = TextEditingController(
      text: assignment != null && assignment.sati > 0
          ? assignment.sati.toStringAsFixed(1)
          : '',
    );
    _loadLookups();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final repo = ref.read(workOrderRepositoryProvider);
      final workers = await repo.fetchWorkers();
      final vehicles = await repo.fetchVehicles();
      if (!mounted) return;

      WorkerLookup? selectedWorker;
      if (widget.assignment?.zaposlenikId != null) {
        for (final w in workers) {
          if (w.id == widget.assignment!.zaposlenikId) {
            selectedWorker = w;
            break;
          }
        }
      } else if (widget.defaultZaposlenikId != null) {
        for (final w in workers) {
          if (w.id == widget.defaultZaposlenikId) {
            selectedWorker = w;
            break;
          }
        }
        selectedWorker ??= WorkerLookup(
          id: widget.defaultZaposlenikId!,
          label: widget.defaultZaposlenikName ?? 'Djelatnik',
        );
      } else if (workers.length == 1) {
        selectedWorker = workers.first;
      }

      VehicleLookup? selectedVehicle = _noneVehicle;
      if (widget.assignment?.voziloId != null) {
        for (final v in vehicles) {
          if (v.id == widget.assignment!.voziloId) {
            selectedVehicle = v;
            break;
          }
        }
      }

      setState(() {
        _workers = workers;
        _vehicles = vehicles;
        _selectedWorker = selectedWorker;
        _selectedVehicle = selectedVehicle ?? _noneVehicle;
        _loading = false;
      });
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

    final worker = _selectedWorker;
    if (worker == null) {
      _showError('Odaberite djelatnika.');
      return;
    }

    if (!widget.fieldwork.canManageZaposlenik(worker.id)) {
      _showError('Nemate dozvolu za unos sati ovog djelatnika.');
      return;
    }

    final vehicleId = _selectedVehicle?.id;
    final clearVozilo = vehicleId == null || vehicleId == 0;
    if (!clearVozilo && !widget.fieldwork.canManageVozilo(vehicleId)) {
      _showError('Nemate dozvolu za odabrani stroj.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(workOrderRepositoryProvider);
      final datum = toApiDate(_date);
      if (_isEdit) {
        await repo.updateAssignment(
          id: widget.assignment!.id,
          datum: datum,
          sati: sati,
          voziloId: clearVozilo ? null : vehicleId,
          clearVozilo: clearVozilo,
        );
      } else {
        await repo.upsertAssignment(
          workOrderId: widget.workOrderId,
          zaposlenikId: worker.id,
          datum: datum,
          sati: sati,
          voziloId: clearVozilo ? null : vehicleId,
          existing: widget.assignment,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _showError(ApiClient.describeError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    final name = widget.assignment!.zaposlenikName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ukloni djelatnika'),
        content: Text(
          'Jeste li sigurni da želite ukloniti „$name" s naloga?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ukloni'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref
          .read(workOrderRepositoryProvider)
          .deleteAssignment(id: widget.assignment!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      _showError(ApiClient.describeError(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final title = _isEdit
        ? widget.assignment!.zaposlenikName
        : 'Unos rada';
    final busy = _saving || _deleting;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Text(_loadError!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else ...[
            if (_workers.isEmpty)
              const Text('Nema dostupnih djelatnika.')
            else
              DropdownButton<WorkerLookup>(
                isExpanded: true,
                value: _selectedWorker,
                hint: const Text('Odaberite djelatnika'),
                items: _workers
                    .map((w) => DropdownMenuItem(value: w, child: Text(w.label)))
                    .toList(),
                onChanged: widget.editable && !_isEdit
                    ? (w) => setState(() => _selectedWorker = w)
                    : null,
              ),
            const SizedBox(height: 12),
            if (_vehicles.isNotEmpty) ...[
              DropdownButton<VehicleLookup>(
                isExpanded: true,
                value: _selectedVehicle,
                items: [
                  DropdownMenuItem(value: _noneVehicle, child: Text(_noneVehicle!.label)),
                  ..._vehicles.map(
                    (v) => DropdownMenuItem(value: v, child: Text(v.label)),
                  ),
                ],
                onChanged: widget.editable
                    ? (v) => setState(() => _selectedVehicle = v)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Datum'),
              subtitle: Text(formatDisplayDate(_date)),
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
            if (widget.editable) ...[
              FilledButton(
                onPressed: busy ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Spremi'),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: busy ? null : _delete,
                  icon: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                  label: Text(
                    'Ukloni s naloga',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ] else
              Text(
                'Uređivanje nije dostupno.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
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
    _date = parseApiDate(widget.vehicle.datum) ?? DateTime.now();
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
            datum: toApiDate(_date),
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
          Text('Stroj bez vozača',
              style: Theme.of(context).textTheme.titleLarge),
          Text(widget.vehicle.voziloLabel,
              style: Theme.of(context).textTheme.titleMedium),
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
            subtitle: Text(formatDisplayDate(_date)),
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
      _showError('Odaberite stroj.');
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
            datum: toApiDate(_date),
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
          Text('Stroj bez vozača',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Za generatore, kompresore i slično.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Text(_loadError!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (_vehicles.isEmpty)
            const Text('Nema dostupnih strojeva.')
          else ...[
            DropdownButton<VehicleLookup>(
              isExpanded: true,
              value: _selected,
              hint: const Text('Odaberite stroj'),
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
              subtitle: Text(formatDisplayDate(_date)),
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

class _WorkItemHoursSheet extends ConsumerStatefulWidget {
  const _WorkItemHoursSheet({required this.workItems});

  final List<WorkItem> workItems;

  @override
  ConsumerState<_WorkItemHoursSheet> createState() =>
      _WorkItemHoursSheetState();
}

class _WorkItemHoursSheetState extends ConsumerState<_WorkItemHoursSheet> {
  WorkItem? _selected;
  final _hoursController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.workItems.length == 1) {
      _selected = widget.workItems.first;
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _itemLabel(WorkItem item) {
    final location = item.locationWithRoadSide;
    if (location.isEmpty) return item.title;
    return '${item.title} — $location';
  }

  Future<void> _save() async {
    final item = _selected;
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odaberite stavku rada.')),
      );
      return;
    }
    final hours =
        double.tryParse(_hoursController.text.replaceAll(',', '.'));
    if (hours == null || hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unesite ispravan broj sati.')),
      );
      return;
    }
    if (hours > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimalno 24 sata po unosu.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(executionRepositoryProvider);
      await repo.createExecution(
        workItemId: item.id,
        quantityExecuted: 0,
        executionDate: toApiDate(_date),
        notes: _notesController.text.trim(),
        laborHours: hours,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.describeError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Unos sati po stavci',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<WorkItem>(
            value: _selected,
            decoration: const InputDecoration(
              labelText: 'Stavka rada',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final item in widget.workItems)
                DropdownMenuItem(
                  value: item,
                  child: Text(
                    _itemLabel(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving ? null : (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Datum'),
            subtitle: Text(formatDisplayDate(_date)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _saving
                ? null
                : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hoursController,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              labelText: 'Radni sati',
              suffixText: 'h',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            enabled: !_saving,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Napomena (opcionalno)',
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
                : const Text('Spremi'),
          ),
        ],
      ),
    );
  }
}
