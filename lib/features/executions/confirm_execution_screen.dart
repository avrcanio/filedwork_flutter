import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../shared/utils/app_dates.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../work_items/work_item_models.dart';
import '../work_orders/work_order_models.dart';
import 'execution_models.dart';
import 'execution_repository.dart';

class ConfirmExecutionScreen extends ConsumerStatefulWidget {
  const ConfirmExecutionScreen({
    super.key,
    required this.item,
    required this.workOrderStatus,
    required this.roster,
  });

  final WorkItem item;
  final String workOrderStatus;
  final List<WorkOrderRosterEntry> roster;

  @override
  ConsumerState<ConfirmExecutionScreen> createState() =>
      _ConfirmExecutionScreenState();
}

class _LaborEntryDraft {
  _LaborEntryDraft({this.zaposlenikId});

  int? zaposlenikId;
  final TextEditingController hoursCtrl = TextEditingController();

  void dispose() => hoursCtrl.dispose();
}

class _ConfirmExecutionScreenState
    extends ConsumerState<ConfirmExecutionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photosBefore = [];
  final List<XFile> _photosAfter = [];
  final List<_LaborEntryDraft> _laborRows = [];

  DateTime _date = DateTime.now();
  bool _submitting = false;
  bool _loadingDayData = false;
  String? _statusMessage;
  bool _laborInitialized = false;
  int? _editingExecutionId;

  static const _maxPhotosPerPhase = 5;

  bool get _isFullyExecutedMode =>
      widget.item.isFullyExecuted || widget.item.remainingQuantity <= 0;

  bool get _showBeforeSection => widget.workOrderStatus == 'in_progress';

  bool get _showAfterSection =>
      widget.workOrderStatus == 'in_progress' ||
      widget.workOrderStatus == 'completed';

  FieldworkCapabilities get _fieldwork =>
      ref.read(authControllerProvider).user?.fieldwork ??
      FieldworkCapabilities.empty;

  bool _isManagerMode(FieldworkCapabilities fieldwork) =>
      fieldwork.canEditHours &&
      (fieldwork.managedZaposlenikIds.isNotEmpty ||
          fieldwork.ownZaposlenikId == null);

  List<WorkOrderRosterEntry> _selectableRoster(FieldworkCapabilities fieldwork) {
    if (_isManagerMode(fieldwork)) {
      return widget.roster
          .where((entry) => fieldwork.canManageZaposlenik(entry.id))
          .toList();
    }
    final ownId = fieldwork.ownZaposlenikId;
    if (ownId == null) return const [];
    return widget.roster.where((entry) => entry.id == ownId).toList();
  }

  @override
  void initState() {
    super.initState();
    if (_isFullyExecutedMode) {
      _qtyCtrl.text = '0';
    } else {
      _qtyCtrl.text = _trim(widget.item.remainingQuantity);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_laborInitialized) return;
    _laborInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExecutionsForDate(_date);
    });
  }

  void _clearLaborRows() {
    for (final row in _laborRows) {
      row.dispose();
    }
    _laborRows.clear();
  }

  String _formatHoursInput(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  Future<void> _loadExecutionsForDate(DateTime date) async {
    if (!mounted) return;
    setState(() {
      _loadingDayData = true;
      _photosBefore.clear();
      _photosAfter.clear();
    });

    try {
      final repo = ref.read(executionRepositoryProvider);
      final executions = await repo.listExecutions(
        workItemId: widget.item.id,
        executionDate: toApiDate(date),
      );

      _clearLaborRows();

      final hoursByWorker = <int, double>{};
      WorkExecution? latest;
      for (final execution in executions) {
        if (latest == null || execution.id > latest.id) {
          latest = execution;
        }
        for (final line in execution.laborLines) {
          hoursByWorker[line.zaposlenikId] =
              (hoursByWorker[line.zaposlenikId] ?? 0) + line.laborHours;
        }
      }

      _editingExecutionId = latest?.id;
      _notesCtrl.text = latest?.notes ?? '';

      if (!_isFullyExecutedMode &&
          latest != null &&
          latest.quantityExecuted > 0) {
        _qtyCtrl.text = _trim(latest.quantityExecuted);
      } else if (!_isFullyExecutedMode) {
        _qtyCtrl.text = _trim(widget.item.remainingQuantity);
      }

      if (hoursByWorker.isNotEmpty) {
        for (final entry in hoursByWorker.entries) {
          final row = _LaborEntryDraft(zaposlenikId: entry.key);
          row.hoursCtrl.text = _formatHoursInput(entry.value);
          _laborRows.add(row);
        }
      } else {
        final selectable = _selectableRoster(_fieldwork);
        if (!_isManagerMode(_fieldwork) && selectable.isNotEmpty) {
          _laborRows.add(_LaborEntryDraft(zaposlenikId: selectable.first.id));
        }
      }
    } catch (error) {
      if (mounted) {
        _showSnack(ApiClient.describeError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDayData = false);
      }
    }
  }

  Future<void> _onDateChanged(DateTime date) async {
    setState(() => _date = date);
    await _loadExecutionsForDate(date);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _clearLaborRows();
    super.dispose();
  }

  String _trim(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  double? _parseHours(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  Future<void> _pickPhoto(ImageSource source, {required bool before}) async {
    final list = before ? _photosBefore : _photosAfter;
    if (list.length >= _maxPhotosPerPhase) {
      _showSnack(
        before
            ? 'Najviše $_maxPhotosPerPhase fotografija prije radova.'
            : 'Najviše $_maxPhotosPerPhase fotografija poslije radova.',
      );
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          if (before) {
            _photosBefore.add(file);
          } else {
            _photosAfter.add(file);
          }
        });
      }
    } catch (_) {
      _showSnack('Nije moguće dohvatiti fotografiju.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<({int zaposlenikId, double laborHours})> _collectLaborEntries() {
    final entries = <({int zaposlenikId, double laborHours})>[];
    for (final row in _laborRows) {
      final hours = _parseHours(row.hoursCtrl.text.trim());
      if (row.zaposlenikId == null || hours == null) continue;
      entries.add((zaposlenikId: row.zaposlenikId!, laborHours: hours));
    }
    return entries;
  }

  bool _hasSupplementaryContent() {
    if (_collectLaborEntries().isNotEmpty) return true;
    final notes = _notesCtrl.text.trim();
    return notes.isNotEmpty ||
        _photosBefore.isNotEmpty ||
        _photosAfter.isNotEmpty;
  }

  void _addLaborRow() {
    setState(() => _laborRows.add(_LaborEntryDraft()));
  }

  void _removeLaborRow(int index) {
    setState(() {
      _laborRows[index].dispose();
      _laborRows.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final qtyText = _qtyCtrl.text.trim();
    final qty = qtyText.isEmpty
        ? 0.0
        : double.parse(qtyText.replaceAll(',', '.'));
    final laborEntries = _collectLaborEntries();
    final repo = ref.read(executionRepositoryProvider);

    if (_isFullyExecutedMode && qty <= 0 && !_hasSupplementaryContent()) {
      _showSnack('Unesite radne sate, napomenu ili fotografije.');
      return;
    }

    setState(() {
      _submitting = true;
      _statusMessage = 'Spremam…';
    });

    try {
      final WorkExecution execution;
      if (_editingExecutionId != null) {
        execution = await repo.updateExecution(
          executionId: _editingExecutionId!,
          quantityExecuted: qty,
          executionDate: toApiDate(_date),
          notes: _notesCtrl.text.trim(),
          laborEntries: laborEntries,
        );
      } else {
        execution = await repo.createExecution(
          workItemId: widget.item.id,
          quantityExecuted: qty,
          executionDate: toApiDate(_date),
          notes: _notesCtrl.text.trim(),
          laborEntries: laborEntries.isEmpty ? null : laborEntries,
        );
      }

      final toUpload = <({XFile file, String phase})>[
        for (final p in _photosBefore) (file: p, phase: 'before'),
        for (final p in _photosAfter) (file: p, phase: 'after'),
      ];

      var uploaded = 0;
      var failed = 0;
      for (final entry in toUpload) {
        if (mounted) {
          setState(() => _statusMessage =
              'Upload fotografija ${uploaded + 1}/${toUpload.length}…');
        }
        try {
          await repo.uploadPhoto(
            executionId: execution.id,
            filePath: entry.file.path,
            phase: entry.phase,
          );
          uploaded++;
        } catch (_) {
          failed++;
        }
      }

      if (!mounted) return;
      if (failed > 0) {
        _showSnack(
            'Spremljeno, ali $failed fotografija nije uploadano.');
      } else {
        _showSnack('Spremljeno.');
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusMessage = null;
      });
      _showSnack(ApiClient.describeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unit = item.unit;
    final fieldwork = _fieldwork;
    final managerMode = _isManagerMode(fieldwork);
    final selectableRoster = _selectableRoster(fieldwork);

    return Scaffold(
      appBar: AppBar(title: const Text('Potvrda izvršenja')),
      body: AbsorbPointer(
        absorbing: _submitting || _loadingDayData,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ItemSummary(item: item),
              if (_isFullyExecutedMode) ...[
                const SizedBox(height: 12),
                Text(
                  'Stavka je u potpunosti odrađena. Možete dodati radne '
                  'sate po djelatniku, napomenu ili fotografije.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 20),
              if (!_isFullyExecutedMode) ...[
                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Izvršena količina ($unit)',
                    prefixIcon: const Icon(Icons.straighten),
                  ),
                  validator: _validateQty,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                        () => _qtyCtrl.text = _trim(item.remainingQuantity)),
                    icon: const Icon(Icons.done_all),
                    label: Text(
                        'Potvrdi cijelu preostalu (${_trim(item.remainingQuantity)} $unit)'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _DatePickerTile(
                date: _date,
                onChanged: (d) => _onDateChanged(d),
              ),
              const SizedBox(height: 8),
              Text(
                'Prikaz i unos sati za odabrani datum rada.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              if (_loadingDayData) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 12),
              _LaborHoursSection(
                roster: widget.roster,
                selectableRoster: selectableRoster,
                rows: _laborRows,
                managerMode: managerMode,
                onAddRow: _addLaborRow,
                onRemoveRow: _removeLaborRow,
                onRowChanged: () => setState(() {}),
                validateRows: _validateLaborRows,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Napomena (opcionalno)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Text('Fotodokumentacija',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Do $_maxPhotosPerPhase fotografija prije i $_maxPhotosPerPhase poslije radova.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_showBeforeSection) ...[
                const SizedBox(height: 16),
                _PhotoSection(
                  title: 'Prije radova',
                  photos: _photosBefore,
                  maxPhotos: _maxPhotosPerPhase,
                  onCamera: () => _pickPhoto(ImageSource.camera, before: true),
                  onGallery: () =>
                      _pickPhoto(ImageSource.gallery, before: true),
                  onRemove: (i) => setState(() => _photosBefore.removeAt(i)),
                ),
              ],
              if (_showAfterSection) ...[
                const SizedBox(height: 16),
                _PhotoSection(
                  title: 'Poslije radova',
                  photos: _photosAfter,
                  maxPhotos: _maxPhotosPerPhase,
                  onCamera: () => _pickPhoto(ImageSource.camera, before: false),
                  onGallery: () =>
                      _pickPhoto(ImageSource.gallery, before: false),
                  onRemove: (i) => setState(() => _photosAfter.removeAt(i)),
                ),
              ],
              const SizedBox(height: 28),
              if (_statusMessage != null) ...[
                Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_statusMessage!)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Spremi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateQty(String? value) {
    if (_isFullyExecutedMode) return null;
    if (value == null || value.trim().isEmpty) return 'Unesite količinu';
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Neispravan broj';
    if (parsed <= 0) return 'Količina mora biti veća od 0';
    if (parsed > widget.item.remainingQuantity + 0.001) {
      return 'Maksimalno ${_trim(widget.item.remainingQuantity)} ${widget.item.unit}';
    }
    return null;
  }

  String? _validateLaborRows() {
    final usedIds = <int>{};
    for (final row in _laborRows) {
      final hoursText = row.hoursCtrl.text.trim();
      final hasHours = hoursText.isNotEmpty;
      if (row.zaposlenikId == null && hasHours) {
        return 'Odaberite djelatnika za unesene sate';
      }
      if (row.zaposlenikId != null && hasHours) {
        final parsed = double.tryParse(hoursText.replaceAll(',', '.'));
        if (parsed == null) return 'Neispravan broj sati';
        if (parsed <= 0) return 'Sati moraju biti veći od 0';
        if (parsed > 24) return 'Maksimalno 24 sata po unosu';
        if (!usedIds.add(row.zaposlenikId!)) {
          return 'Svaki djelatnik smije imati samo jedan red sati';
        }
      }
      if (row.zaposlenikId != null && !hasHours) {
        return 'Unesite sate za odabranog djelatnika';
      }
    }
    if (_isFullyExecutedMode && !_hasSupplementaryContent()) {
      return 'Unesite sate, napomenu ili fotografije';
    }
    return null;
  }
}

class _LaborHoursSection extends StatelessWidget {
  const _LaborHoursSection({
    required this.roster,
    required this.selectableRoster,
    required this.rows,
    required this.managerMode,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onRowChanged,
    required this.validateRows,
  });

  final List<WorkOrderRosterEntry> roster;
  final List<WorkOrderRosterEntry> selectableRoster;
  final List<_LaborEntryDraft> rows;
  final bool managerMode;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onRowChanged;
  final String? Function() validateRows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Radni sati po djelatniku',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (roster.isEmpty)
          Text(
            'Nema djelatnika na nalogu. Dodajte ih u web aplikaciji.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          )
        else if (selectableRoster.isEmpty)
          Text(
            'Nemate dodijeljenih djelatnika za unos sati na ovom nalogu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          )
        else ...[
          FormField<void>(
            validator: (_) => validateRows(),
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < rows.length; i++)
                    _LaborEntryRow(
                      key: ValueKey('labor-$i-${rows[i].zaposlenikId}'),
                      row: rows[i],
                      selectableRoster: selectableRoster,
                      managerMode: managerMode,
                      canRemove: managerMode,
                      onChanged: () {
                        onRowChanged();
                        state.didChange(null);
                      },
                      onRemove: () => onRemoveRow(i),
                    ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        state.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (managerMode)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddRow,
                icon: const Icon(Icons.add),
                label: const Text('Dodaj djelatnika'),
              ),
            ),
        ],
      ],
    );
  }
}

class _LaborEntryRow extends StatelessWidget {
  const _LaborEntryRow({
    super.key,
    required this.row,
    required this.selectableRoster,
    required this.managerMode,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _LaborEntryDraft row;
  final List<WorkOrderRosterEntry> selectableRoster;
  final bool managerMode;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: managerMode
                ? DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: row.zaposlenikId,
                    decoration: const InputDecoration(
                      labelText: 'Djelatnik',
                      isDense: true,
                    ),
                    items: [
                      for (final entry in selectableRoster)
                        DropdownMenuItem(
                          value: entry.id,
                          child: Text(
                            shortWorkerDisplayName(entry.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      row.zaposlenikId = value;
                      onChanged();
                    },
                  )
                : InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Djelatnik',
                      isDense: true,
                    ),
                    child: Text(
                      selectableRoster.isNotEmpty
                          ? shortWorkerDisplayName(selectableRoster.first.name)
                          : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.hoursCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*[.,]?\d{0,2}'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Sati',
                suffixText: 'h',
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (canRemove)
            IconButton(
              tooltip: 'Ukloni red',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _ItemSummary extends StatelessWidget {
  const _ItemSummary({required this.item});

  final WorkItem item;

  @override
  Widget build(BuildContext context) {
    final unit = item.unit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            if (item.locationWithRoadSide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(item.locationWithRoadSide,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Metric(
                    label: 'Planirano',
                    value: '${item.quantity.toStringAsFixed(0)} $unit'),
                _Metric(
                    label: 'Odrađeno',
                    value:
                        '${item.executedQuantity.toStringAsFixed(0)} $unit'),
                _Metric(
                    label: 'Preostalo',
                    value:
                        '${item.remainingQuantity.toStringAsFixed(0)} $unit',
                    highlight: true),
              ],
            ),
            if (item.totalLaborHours > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Ukupno sati na stavci: ${item.totalLaborHours.toStringAsFixed(1)} h',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: highlight ? scheme.primary : null,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: const Text('Datum izvršenja'),
        subtitle: Text(formatDisplayDate(date)),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
          );
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.title,
    required this.photos,
    required this.maxPhotos,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final String title;
  final List<XFile> photos;
  final int maxPhotos;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Kamera'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galerija'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${photos.length}/$maxPhotos fotografija',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < photos.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(photos[i].path),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => onRemove(i),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}
