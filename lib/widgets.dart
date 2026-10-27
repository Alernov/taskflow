import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

/// Круглая отметка выполнения (как в Google Задачах).
class DoneCircle extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;

  const DoneCircle({super.key, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? TaskStatus.done.color : scheme.outline,
          size: 26,
        ),
      ),
    );
  }
}

/// Маленький кружок с инициалами исполнителя.
class PersonAvatar extends StatelessWidget {
  final Person person;
  final double size;

  const PersonAvatar({super.key, required this.person, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        person.initials,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Плашка с ключом задачи, например TASK-12.
class KeyBadge extends StatelessWidget {
  final String text;
  final Color color;

  const KeyBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(36),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

bool isOverdue(Task t) {
  if (t.due == null || t.isDone) return false;
  return dateOnly(t.due!).isBefore(dateOnly(DateTime.now()));
}

/// Строка мелких меток под названием задачи: ключ, приоритет, срок, исполнитель, подзадачи.
class TaskMeta extends StatelessWidget {
  final Task task;
  final bool showStatus;

  const TaskMeta({super.key, required this.task, this.showStatus = false});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final queue = store.queueById(task.queueId);
    final person = store.personById(task.assigneeId);
    final overdue = isOverdue(task);
    final doneSubs = task.subtasks.where((s) => s.done).length;

    final items = <Widget>[
      KeyBadge(
        text: store.keyOf(task),
        color: queue?.color ?? scheme.primary,
      ),
    ];

    if (task.priority != Priority.normal) {
      items.add(
        Icon(task.priority.icon, size: 18, color: task.priority.color),
      );
    }

    if (task.due != null) {
      final color = overdue ? scheme.error : scheme.onSurfaceVariant;
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event, size: 14, color: color),
            const SizedBox(width: 3),
            Text(
              formatDue(task.due!),
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      );
    }

    if (task.subtasks.isNotEmpty) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Text(
              '$doneSubs/${task.subtasks.length}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (showStatus) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(task.status.icon, size: 14, color: task.status.color),
            const SizedBox(width: 3),
            Text(
              task.status.label,
              style: TextStyle(fontSize: 12, color: task.status.color),
            ),
          ],
        ),
      );
    }

    if (person != null) {
      items.add(PersonAvatar(person: person));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}

/// Горизонтальная панель фильтров: очередь + исполнитель.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    final chips = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: const Text('Все очереди'),
          selected: store.filterQueueId == null,
          onSelected: (_) => store.setFilterQueue(null),
        ),
      ),
    ];

    for (final q in store.queues) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            avatar: CircleAvatar(backgroundColor: q.color, radius: 6),
            label: Text(q.name),
            selected: store.filterQueueId == q.id,
            onSelected: (_) => store.setFilterQueue(q.id),
          ),
        ),
      );
    }

    final person = store.personById(store.filterPersonId);

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: chips,
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Все исполнители'),
                  selected: person == null,
                  onSelected: (_) => store.setFilterPerson(null),
                ),
              ),
              for (final p in store.people)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: PersonAvatar(person: p, size: 20),
                    label: Text(p.name),
                    selected: store.filterPersonId == p.id,
                    onSelected: (_) => store.setFilterPerson(p.id),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 8, color: scheme.outlineVariant),
      ],
    );
  }
}

/// Меню смены статуса.
Future<void> pickStatus(BuildContext context, Task task) async {
  final store = StoreScope.of(context);
  final result = await showModalBottomSheet<TaskStatus>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in TaskStatus.values)
            ListTile(
              leading: Icon(s.icon, color: s.color),
              title: Text(s.label),
              trailing: s == task.status ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    ),
  );
  if (result != null) store.setStatus(task, result);
}
