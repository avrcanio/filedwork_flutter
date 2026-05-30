import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../shared/utils/app_dates.dart';
import '../work_items/work_item_models.dart';
import 'execution_repository.dart';

class ConfirmExecutionScreen extends ConsumerStatefulWidget {
  const ConfirmExecutionScreen({
    super.key,
    required this.item,
    required this.workOrderStatus,
  });

  final WorkItem item;
  final String workOrderStatus;

  @override
  ConsumerState<ConfirmExecutionScreen> createState() =>
      _ConfirmExecutionScreenState();
}

class _ConfirmExecutionScreenState
    extends ConsumerState<ConfirmExecutionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _photosBefore = [];
  final List<XFile> _photosAfter = [];

  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _statusMessage;

  static const _maxPhotosPerPhase = 5;

  bool get _showBeforeSection => widget.workOrderStatus == 'in_progress';

  bool get _showAfterSection =>
      widget.workOrderStatus == 'in_progress' ||
      widget.workOrderStatus == 'completed';

  @override
  void initState() {
    super.initState();
    _qtyCtrl.text = _trim(widget.item.remainingQuantity);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _trim(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final qty = double.parse(_qtyCtrl.text.replaceAll(',', '.'));
    final repo = ref.read(executionRepositoryProvider);

    setState(() {
      _submitting = true;
      _statusMessage = 'Spremam izvršenje…';
    });

    try {
      final execution = await repo.createExecution(
        workItemId: widget.item.id,
        quantityExecuted: qty,
        executionDate: toApiDate(_date),
        notes: _notesCtrl.text.trim(),
      );

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
            'Izvršenje spremljeno, ali $failed fotografija nije uploadano.');
      } else {
        _showSnack('Izvršenje spremljeno.');
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

    return Scaffold(
      appBar: AppBar(title: const Text('Potvrda izvršenja')),
      body: AbsorbPointer(
        absorbing: _submitting,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ItemSummary(item: item),
              const SizedBox(height: 20),
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
              _DatePickerTile(
                date: _date,
                onChanged: (d) => setState(() => _date = d),
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
                label: const Text('Spremi izvršenje'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateQty(String? value) {
    if (value == null || value.trim().isEmpty) return 'Unesite količinu';
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) return 'Neispravan broj';
    if (parsed <= 0) return 'Količina mora biti veća od 0';
    if (parsed > widget.item.remainingQuantity + 0.001) {
      return 'Maksimalno ${_trim(widget.item.remainingQuantity)} ${widget.item.unit}';
    }
    return null;
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
