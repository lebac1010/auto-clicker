import 'package:auto_clicker/data/schedule_repository.dart';
import 'package:auto_clicker/data/script_repository.dart';
import 'package:auto_clicker/models/permission_state.dart';
import 'package:auto_clicker/models/schedule_model.dart';
import 'package:auto_clicker/models/script_model.dart';
import 'package:auto_clicker/services/permission_service.dart';
import 'package:auto_clicker/services/scheduler_service.dart';
import 'package:flutter/material.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  final ScheduleRepository _scheduleRepository = ScheduleRepository.instance;
  final ScriptRepository _scriptRepository = ScriptRepository.instance;
  List<ScheduleModel> _schedules = const <ScheduleModel>[];
  List<ScriptModel> _scripts = const <ScriptModel>[];
  bool _loading = true;
  PermissionState _permissionState = PermissionState.fallback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final schedules = await _scheduleRepository.listSchedules();
    final scripts = await _scriptRepository.listScripts();
    final permissions = await PermissionService.getPermissionState();
    if (!mounted) {
      return;
    }
    setState(() {
      _schedules = schedules;
      _scripts = scripts;
      _permissionState = permissions;
      _loading = false;
    });
  }

  Future<void> _createOrEdit({ScheduleModel? existing}) async {
    final result = await showDialog<ScheduleModel>(
      context: context,
      builder: (_) => _ScheduleDialog(
        scripts: _scripts,
        initial: existing,
      ),
    );
    if (result == null) {
      return;
    }
    try {
      if (existing == null) {
        await _scheduleRepository.createSchedule(
          scriptId: result.scriptId,
          type: result.type,
          timeOfDay: result.timeOfDay,
          weekdays: result.weekdays,
          onceAt: result.onceAt,
        );
      } else {
        await _scheduleRepository.saveSchedule(
          result.copyWith(updatedAt: DateTime.now()),
        );
      }
      await SchedulerService.instance.reschedule();
      await _load();
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _toggle(ScheduleModel schedule, bool enabled) async {
    await _scheduleRepository.saveSchedule(
      schedule.copyWith(
        enabled: enabled,
        updatedAt: DateTime.now(),
      ),
    );
    await SchedulerService.instance.reschedule();
    await _load();
  }

  Future<void> _delete(ScheduleModel schedule) async {
    await _scheduleRepository.deleteSchedule(schedule.id);
    await SchedulerService.instance.reschedule();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduler'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scripts.isEmpty ? null : () => _createOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('New Schedule'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scripts.isEmpty
          ? const Center(
              child: Text('Create at least one script before scheduling.'),
            )
          : Column(
              children: [
                if (!_permissionState.exactAlarmAllowed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Material(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: const Icon(
                          Icons.schedule,
                          color: Color(0xFFE65100),
                        ),
                        title: const Text('Exact alarm is OFF'),
                        subtitle: const Text(
                          'Enable exact alarm for reliable on-time scheduler triggers.',
                        ),
                        trailing: OutlinedButton(
                          onPressed: () async {
                            await PermissionService.requestExactAlarm();
                            await _load();
                          },
                          child: const Text('Enable'),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _schedules.isEmpty
                      ? const Center(child: Text('No schedules yet.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _schedules.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final schedule = _schedules[index];
                            ScriptModel? script;
                            for (final item in _scripts) {
                              if (item.id == schedule.scriptId) {
                                script = item;
                                break;
                              }
                            }
                            return Card(
                              child: ListTile(
                                title: Text(script?.name ?? schedule.scriptId),
                                subtitle: Text(_describe(schedule)),
                                leading: Switch(
                                  value: schedule.enabled,
                                  onChanged: (value) => _toggle(schedule, value),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _createOrEdit(existing: schedule);
                                    } else if (value == 'delete') {
                                      _delete(schedule);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _describe(ScheduleModel schedule) {
    switch (schedule.type) {
      case ScheduleType.daily:
        return 'Daily at ${schedule.timeOfDay ?? '--:--'}';
      case ScheduleType.weekly:
        final days = schedule.weekdays.map(_weekdayLabel).join(', ');
        return 'Weekly [$days] at ${schedule.timeOfDay ?? '--:--'}';
      case ScheduleType.once:
        return 'One-time at ${schedule.onceAt?.toString() ?? 'N/A'}';
    }
  }

  String _weekdayLabel(int value) {
    switch (value) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return value.toString();
    }
  }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({
    required this.scripts,
    this.initial,
  });

  final List<ScriptModel> scripts;
  final ScheduleModel? initial;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late String _scriptId;
  late ScheduleType _type;
  late final TextEditingController _timeController;
  late final TextEditingController _onceController;
  Set<int> _weekdays = <int>{};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _scriptId = initial?.scriptId ?? widget.scripts.first.id;
    _type = initial?.type ?? ScheduleType.daily;
    _timeController = TextEditingController(text: initial?.timeOfDay ?? '09:00');
    _onceController = TextEditingController(
      text: initial?.onceAt?.toIso8601String() ?? '',
    );
    _weekdays = initial == null
        ? <int>{DateTime.monday}
        : initial.weekdays.toSet();
  }

  @override
  void dispose() {
    _timeController.dispose();
    _onceController.dispose();
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now();
    final model = ScheduleModel(
      id: widget.initial?.id ?? 'sch_tmp_${now.microsecondsSinceEpoch}',
      scriptId: _scriptId,
      type: _type,
      enabled: widget.initial?.enabled ?? true,
      createdAt: widget.initial?.createdAt ?? now,
      updatedAt: now,
      timeOfDay: _type == ScheduleType.once ? null : _timeController.text.trim(),
      weekdays: _type == ScheduleType.weekly
          ? (_weekdays.toList()..sort())
          : const <int>[],
      onceAt: _type == ScheduleType.once
          ? DateTime.tryParse(_onceController.text.trim())
          : null,
      lastTriggeredAt: widget.initial?.lastTriggeredAt,
    );
    final errors = model.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errors.first)));
      return;
    }
    Navigator.of(context).pop(model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Create Schedule' : 'Edit Schedule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _scriptId,
              decoration: const InputDecoration(labelText: 'Script'),
              items: widget.scripts
                  .map(
                    (script) => DropdownMenuItem(
                      value: script.id,
                      child: Text(script.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _scriptId = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ScheduleType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(
                  value: ScheduleType.daily,
                  child: Text('Daily'),
                ),
                DropdownMenuItem(
                  value: ScheduleType.weekly,
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: ScheduleType.once,
                  child: Text('One-time'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            if (_type != ScheduleType.once)
              TextField(
                controller: _timeController,
                decoration: const InputDecoration(
                  labelText: 'Time (HH:mm)',
                ),
              ),
            if (_type == ScheduleType.weekly) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List<Widget>.generate(7, (index) {
                  final weekday = index + 1;
                  final selected = _weekdays.contains(weekday);
                  return FilterChip(
                    label: Text(_shortDay(weekday)),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _weekdays.add(weekday);
                        } else {
                          _weekdays.remove(weekday);
                        }
                      });
                    },
                  );
                }),
              ),
            ],
            if (_type == ScheduleType.once)
              TextField(
                controller: _onceController,
                decoration: const InputDecoration(
                  labelText: 'Date-time (ISO)',
                  hintText: '2026-02-24T08:30:00',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _shortDay(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '?';
    }
  }
}
