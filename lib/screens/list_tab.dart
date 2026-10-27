import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'task_editor.dart';

/// Вкладка «Список» - простой список в духе Google Задач.
class ListTab extends StatefulWidget {
  const ListTab({super.key});

  @override
  State<ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<ListTab> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _quickQueueId;
  bool _showDone = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _effectiveQueueId(Store store) {
    if (store.filterQueueId != null) return store.filterQueueId!;
    if (_quickQueueId != null && store.queueById(_quickQueueId) != null) {
      return _quickQueueId!;
    }
    return store.queues.first.id;
  }

  void _quickAdd(Store store) {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    store.addTask(
      title: text,
      queueId: _effectiveQueueId(store),
      assigneeId: store.filterPersonId,
    );
    _ctrl.clear();
    _focus.requestFocus();
  }

  Widget _quickAddBar(Store store) {
    final q = store.queueById(_effectiveQueueId(store))!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withAlpha(110),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            PopupMenuButton<String>(
              tooltip: 'Очередь',
              enabled: store.filterQueueId == null && store.queues.length > 1,
              onSelected: (id) => setState(() => _quickQueueId = id),
              itemBuilder: (_) => [
                for (final queue in store.queues)
                  PopupMenuItem<String>(
                    value: queue.id,
                    child: Text('${queue.key} · ${queue.name}'),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 6),
                child: KeyBadge(text: q.key, color: q.color),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _quickAdd(store),
                decoration: const InputDecoration(
                  hintText: 'Новая задача',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Добавить',
              icon: const Icon(Icons.arrow_upward),
              onPressed: () => _quickAdd(store),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _subRow(Store store, Task t, SubTask s) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => store.toggleSubtask(t, s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              s.done ? Icons.check_circle_outline : Icons.circle_outlined,
              size: 18,
              color: s.done ? TaskStatus.done.color : scheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.title,
                style: TextStyle(
                  fontSize: 14,
                  decoration: s.done ? TextDecoration.lineThrough : null,
                  color: s.done ? scheme.outline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Store store, Task t) {
    final scheme = Theme.of(context).colorScheme;
    final showStatus = t.status == TaskStatus.inProgress ||
        t.status == TaskStatus.review;

    return Dismissible(
      key: ValueKey('tile_${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        store.deleteTask(t);
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Задача удалена'),
            action: SnackBarAction(
              label: 'Отменить',
              onPressed: () => store.restoreTask(t),
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () => openTaskEditor(context, t.copy(), isNew: false),
        onLongPress: () => pickStatus(context, t),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoneCircle(done: t.isDone, onTap: () => store.toggleDone(t)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 16,
                          decoration:
                              t.isDone ? TextDecoration.lineThrough : null,
                          color: t.isDone ? scheme.outline : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TaskMeta(task: t, showStatus: showStatus),
                      if (t.subtasks.isNotEmpty) const SizedBox(height: 4),
                      for (final s in t.subtasks.take(6)) _subRow(store, t, s),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _group(
    Store store,
    String title,
    List<Task> tasks, {
    Color? color,
  }) {
    if (tasks.isEmpty) return const [];
    return [
      _header('$title · ${tasks.length}', color: color),
      for (final t in tasks) _tile(store, t),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    final all = store.visibleTasks;
    final active = all.where((t) => !t.isDone).toList();
    final done = all.where((t) => t.isDone).toList();

    final today = dateOnly(DateTime.now());
    final overdue = <Task>[];
    final todayList = <Task>[];
    final later = <Task>[];
    final noDate = <Task>[];
    for (final t in active) {
      if (t.due == null) {
        noDate.add(t);
        continue;
      }
      final d = dateOnly(t.due!);
      if (d.isBefore(today)) {
        overdue.add(t);
      } else if (d.isAtSameMomentAs(today)) {
        todayList.add(t);
      } else {
        later.add(t);
      }
    }
    int byDue(Task a, Task b) {
      final c = a.due!.compareTo(b.due!);
      return c != 0 ? c : store.compareTasks(a, b);
    }

    overdue.sort(byDue);
    later.sort(byDue);

    final children = <Widget>[
      ..._group(store, 'Просрочено', overdue, color: scheme.error),
      ..._group(store, 'Сегодня', todayList),
      ..._group(store, 'Позже', later),
      ..._group(store, 'Без срока', noDate),
    ];

    if (done.isNotEmpty) {
      children.add(
        InkWell(
          onTap: () => setState(() => _showDone = !_showDone),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Text(
                  'Выполнено · ${done.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showDone ? Icons.expand_less : Icons.expand_more,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
      if (_showDone) {
        for (final t in done) {
          children.add(_tile(store, t));
        }
      }
    }

    return Column(
      children: [
        _quickAddBar(store),
        Expanded(
          child: all.isEmpty
              ? Center(
                  child: Text(
                    'Задач пока нет.\nДобавьте первую в поле выше.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.outline),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: children,
                ),
        ),
      ],
    );
  }
}
