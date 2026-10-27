import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

/// Вкладка «Управление»: очереди, исполнители, резервная копия.
class ManageTab extends StatelessWidget {
  const ManageTab({super.key});

  Widget _title(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
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

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(BuildContext context, String text, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _editQueue(BuildContext context, Store store, TaskQueue? q) {
    return showDialog<void>(
      context: context,
      builder: (_) => _QueueDialog(store: store, queue: q),
    );
  }

  Future<void> _editPerson(BuildContext context, Store store, Person? p) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: p == null ? 'Новый исполнитель' : 'Переименовать',
        hint: 'Имя',
        initial: p?.name ?? '',
      ),
    );
    if (name == null) return;
    if (p == null) {
      store.addPerson(name);
    } else {
      store.renamePerson(p, name);
    }
  }

  Future<void> _backup(BuildContext context, Store store) async {
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    if (context.mounted) {
      _snack(context, 'Данные скопированы в буфер обмена');
    }
  }

  Future<void> _restore(BuildContext context, Store store) async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (!context.mounted) return;
    if (text.trim().isEmpty) {
      _snack(context, 'Буфер обмена пуст');
      return;
    }
    final ok = await _confirm(
      context,
      'Заменить все текущие данные теми, что лежат в буфере обмена?',
      'Заменить',
    );
    if (!ok) return;
    final error = await store.importJson(text);
    if (context.mounted) {
      _snack(context, error ?? 'Данные восстановлены');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _title(context, 'ОЧЕРЕДИ'),
        for (final q in store.queues)
          ListTile(
            leading: CircleAvatar(backgroundColor: q.color, radius: 12),
            title: Text(q.name),
            subtitle: Text(
              '${q.key} · задач: ${store.tasks.where((t) => t.queueId == q.id).length}',
            ),
            onTap: () => _editQueue(context, store, q),
            trailing: store.queues.length > 1
                ? IconButton(
                    tooltip: 'Удалить очередь',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await _confirm(
                        context,
                        'Удалить очередь «${q.name}» вместе со всеми её задачами?',
                        'Удалить',
                      );
                      if (ok) store.deleteQueue(q);
                    },
                  )
                : null,
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Добавить очередь'),
          onTap: () => _editQueue(context, store, null),
        ),
        _title(context, 'ИСПОЛНИТЕЛИ'),
        for (final p in store.people)
          ListTile(
            leading: PersonAvatar(person: p, size: 32),
            title: Text(p.name),
            onTap: () => _editPerson(context, store, p),
            trailing: IconButton(
              tooltip: 'Удалить исполнителя',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await _confirm(
                  context,
                  'Удалить исполнителя «${p.name}»? Его задачи останутся без исполнителя.',
                  'Удалить',
                );
                if (ok) store.deletePerson(p);
              },
            ),
          ),
        ListTile(
          leading: const Icon(Icons.person_add_alt),
          title: const Text('Добавить исполнителя'),
          onTap: () => _editPerson(context, store, null),
        ),
        _title(context, 'ДАННЫЕ'),
        ListTile(
          leading: const Icon(Icons.copy_all),
          title: const Text('Скопировать данные'),
          subtitle: const Text('Резервная копия в буфер обмена'),
          onTap: () => _backup(context, store),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Восстановить из буфера'),
          subtitle: const Text('Вставить ранее скопированные данные'),
          onTap: () => _restore(context, store),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Text(
            'Все данные хранятся только на этом телефоне.',
            style: TextStyle(color: scheme.outline, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Диалог с одним текстовым полем.
class _TextDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String initial;

  const _TextDialog({
    required this.title,
    required this.hint,
    required this.initial,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final text = _c.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _ok(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Готово')),
      ],
    );
  }
}

/// Диалог создания и редактирования очереди.
class _QueueDialog extends StatefulWidget {
  final Store store;
  final TaskQueue? queue;

  const _QueueDialog({required this.store, required this.queue});

  @override
  State<_QueueDialog> createState() => _QueueDialogState();
}

class _QueueDialogState extends State<_QueueDialog> {
  late final TextEditingController _name;
  late final TextEditingController _key;
  late int _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.queue;
    _name = TextEditingController(text: q?.name ?? '');
    _key = TextEditingController(text: q?.key ?? '');
    _color = q?.colorValue ?? queueColors[widget.store.queues.length % queueColors.length];
  }

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    super.dispose();
  }

  void _save() {
    final error = widget.store.saveQueue(
      id: widget.queue?.id,
      key: _key.text,
      name: _name.text,
      colorValue: _color,
    );
    if (error != null) {
      setState(() => _error = error);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.queue == null ? 'Новая очередь' : 'Очередь'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.queue == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _key,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Ключ (латиница, например HOME)',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in queueColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: _color == c
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
