import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

/// Черновик новой задачи с учётом активных фильтров.
Task newTaskDraft(Store store, {TaskStatus status = TaskStatus.open}) {
  return Task(
    id: newId(),
    queueId: store.filterQueueId ?? store.queues.first.id,
    number: 0,
    title: '',
    status: status,
    assigneeId: store.filterPersonId,
  );
}

Future<void> openTaskEditor(
  BuildContext context,
  Task task, {
  required bool isNew,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TaskEditorScreen(task: task, isNew: isNew),
    ),
  );
}

class TaskEditorScreen extends StatefulWidget {
  final Task task;
  final bool isNew;

  const TaskEditorScreen({super.key, required this.task, required this.isNew});

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final Task _t;
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final _sub = TextEditingController();

  @override
  void initState() {
    super.initState();
    _t = widget.task;
    _title = TextEditingController(text: _t.title);
    _notes = TextEditingController(text: _t.notes);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _sub.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final text = _sub.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _t.subtasks.add(SubTask(id: newId(), title: text));
      _sub.clear();
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название задачи')),
      );
      return;
    }
    _addSubtask();
    _t.title = title;
    _t.notes = _notes.text.trim();
    StoreScope.of(context).saveTask(_t);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final store = StoreScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить задачу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      store.deleteTask(_t);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _t.due ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _t.due = dateOnly(picked));
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final queue = store.queueById(_t.queueId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew ? 'Новая задача' : '${queue?.key ?? '?'}-${_t.number}',
        ),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('Сохранить')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          TextField(
            controller: _title,
            autofocus: widget.isNew,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Название',
              border: InputBorder.none,
            ),
          ),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Описание',
              prefixIcon: const Icon(Icons.notes),
              filled: true,
              fillColor: scheme.secondaryContainer.withAlpha(70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          _label('ОЧЕРЕДЬ'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final q in store.queues)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: q.color, radius: 6),
                  label: Text('${q.key} · ${q.name}'),
                  selected: _t.queueId == q.id,
                  onSelected: (_) => setState(() => _t.queueId = q.id),
                ),
            ],
          ),
          _label('СТАТУС'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in TaskStatus.values)
                ChoiceChip(
                  avatar: Icon(s.icon, size: 18, color: s.color),
                  label: Text(s.label),
                  selected: _t.status == s,
                  onSelected: (_) => setState(() => _t.status = s),
                ),
            ],
          ),
          _label('ПРИОРИТЕТ'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in Priority.values)
                ChoiceChip(
                  avatar: Icon(p.icon, size: 18, color: p.color),
                  label: Text(p.label),
                  selected: _t.priority == p,
                  onSelected: (_) => setState(() => _t.priority = p),
                ),
            ],
          ),
          _label('ИСПОЛНИТЕЛЬ'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Не назначен'),
                selected: _t.assigneeId == null,
                onSelected: (_) => setState(() => _t.assigneeId = null),
              ),
              for (final p in store.people)
                ChoiceChip(
                  label: Text(p.name),
                  selected: _t.assigneeId == p.id,
                  onSelected: (_) => setState(() => _t.assigneeId = p.id),
                ),
            ],
          ),
          _label('СРОК'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ActionChip(
                avatar: const Icon(Icons.event, size: 18),
                label: Text(_t.due == null ? 'Выбрать дату' : formatDue(_t.due!)),
                onPressed: _pickDate,
              ),
              ActionChip(
                label: const Text('Сегодня'),
                onPressed: () =>
                    setState(() => _t.due = dateOnly(DateTime.now())),
              ),
              ActionChip(
                label: const Text('Завтра'),
                onPressed: () => setState(
                  () => _t.due =
                      dateOnly(DateTime.now()).add(const Duration(days: 1)),
                ),
              ),
              if (_t.due != null)
                ActionChip(
                  avatar: const Icon(Icons.close, size: 18),
                  label: const Text('Убрать'),
                  onPressed: () => setState(() => _t.due = null),
                ),
            ],
          ),
          _label('ПОДЗАДАЧИ'),
          for (final s in _t.subtasks)
            Row(
              children: [
                Checkbox(
                  value: s.done,
                  onChanged: (v) => setState(() => s.done = v ?? false),
                ),
                Expanded(
                  child: Text(
                    s.title,
                    style: TextStyle(
                      decoration: s.done ? TextDecoration.lineThrough : null,
                      color: s.done ? scheme.outline : null,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Удалить подзадачу',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _t.subtasks.remove(s)),
                ),
              ],
            ),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.add),
              ),
              Expanded(
                child: TextField(
                  controller: _sub,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _addSubtask(),
                  decoration: const InputDecoration(
                    hintText: 'Добавить подзадачу',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
