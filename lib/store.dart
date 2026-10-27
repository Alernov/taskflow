import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const queueColors = <int>[
  0xFF5C6BC0,
  0xFF26A69A,
  0xFFEF6C00,
  0xFFAB47BC,
  0xFF43A047,
  0xFFD81B60,
  0xFF00ACC1,
  0xFF8D6E63,
];

class Store extends ChangeNotifier {
  static const _prefsKey = 'taskflow_data_v1';

  List<TaskQueue> queues = [];
  List<Person> people = [];
  List<Task> tasks = [];

  // Общие фильтры для списка и доски.
  String? filterQueueId;
  String? filterPersonId;
  String search = '';

  bool loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      _seed();
    } else {
      try {
        _importMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _seed();
      }
    }
    loaded = true;
    notifyListeners();
  }

  void _seed() {
    queues = [
      TaskQueue(
        id: newId(),
        key: 'TASK',
        name: 'Мои задачи',
        colorValue: queueColors[0],
      ),
    ];
    people = [Person(id: newId(), name: 'Я')];
    tasks = [];
  }

  void _importMap(Map<String, dynamic> m) {
    queues = ((m['queues'] as List?) ?? const [])
        .map((e) => TaskQueue.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    people = ((m['people'] as List?) ?? const [])
        .map((e) => Person.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    tasks = ((m['tasks'] as List?) ?? const [])
        .map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (queues.isEmpty) {
      queues = [
        TaskQueue(
          id: newId(),
          key: 'TASK',
          name: 'Мои задачи',
          colorValue: queueColors[0],
        ),
      ];
    }
  }

  Map<String, dynamic> toMap() => {
        'queues': queues.map((q) => q.toJson()).toList(),
        'people': people.map((p) => p.toJson()).toList(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  String exportJson() => const JsonEncoder.withIndent(' ').convert(toMap());

  /// Возвращает null, если всё хорошо, иначе текст ошибки.
  Future<String?> importJson(String text) async {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return 'Неверный формат данных';
      _importMap(decoded);
      filterQueueId = null;
      filterPersonId = null;
      await _changed();
      return null;
    } catch (e) {
      return 'Не удалось прочитать данные';
    }
  }

  Future<void> _changed() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toMap()));
  }

  // ---------- Поиск ----------

  TaskQueue? queueById(String? id) {
    if (id == null) return null;
    for (final q in queues) {
      if (q.id == id) return q;
    }
    return null;
  }

  Person? personById(String? id) {
    if (id == null) return null;
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  String keyOf(Task t) {
    final q = queueById(t.queueId);
    return '${q?.key ?? '?'}-${t.number}';
  }

  // ---------- Фильтры ----------

  void setFilterQueue(String? id) {
    filterQueueId = id;
    notifyListeners();
  }

  void setFilterPerson(String? id) {
    filterPersonId = id;
    notifyListeners();
  }

  void setSearch(String s) {
    search = s;
    notifyListeners();
  }

  List<Task> get visibleTasks {
    final needle = search.trim().toLowerCase();
    final result = tasks.where((t) {
      if (filterQueueId != null && t.queueId != filterQueueId) return false;
      if (filterPersonId != null && t.assigneeId != filterPersonId) {
        return false;
      }
      if (needle.isNotEmpty) {
        final hay = '${t.title} ${t.notes} ${keyOf(t)}'.toLowerCase();
        if (!hay.contains(needle)) return false;
      }
      return true;
    }).toList();
    result.sort(compareTasks);
    return result;
  }

  /// Сортировка: приоритет, потом срок, потом дата создания.
  int compareTasks(Task a, Task b) {
    final p = a.priority.rank.compareTo(b.priority.rank);
    if (p != 0) return p;
    if (a.due != null && b.due != null) {
      final d = a.due!.compareTo(b.due!);
      if (d != 0) return d;
    } else if (a.due != null) {
      return -1;
    } else if (b.due != null) {
      return 1;
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  // ---------- Задачи ----------

  Task addTask({
    required String title,
    required String queueId,
    String? assigneeId,
    TaskStatus status = TaskStatus.open,
  }) {
    final q = queueById(queueId)!;
    q.counter += 1;
    final t = Task(
      id: newId(),
      queueId: queueId,
      number: q.counter,
      title: title,
      assigneeId: assigneeId,
      status: status,
    );
    tasks.add(t);
    _changed();
    return t;
  }

  /// Сохранение результата из редактора (новая или существующая задача).
  void saveTask(Task edited) {
    final index = tasks.indexWhere((t) => t.id == edited.id);
    if (index == -1) {
      final q = queueById(edited.queueId)!;
      q.counter += 1;
      edited.number = q.counter;
      tasks.add(edited);
    } else {
      final old = tasks[index];
      if (old.queueId != edited.queueId) {
        final q = queueById(edited.queueId)!;
        q.counter += 1;
        edited.number = q.counter;
      }
      tasks[index] = edited;
    }
    _changed();
  }

  void setStatus(Task t, TaskStatus s) {
    if (t.status == s) return;
    t.status = s;
    _changed();
  }

  void toggleDone(Task t) {
    t.status = t.isDone ? TaskStatus.open : TaskStatus.done;
    if (t.isDone) {
      for (final s in t.subtasks) {
        s.done = true;
      }
    }
    _changed();
  }

  void toggleSubtask(Task t, SubTask s) {
    s.done = !s.done;
    _changed();
  }

  void deleteTask(Task t) {
    tasks.removeWhere((x) => x.id == t.id);
    _changed();
  }

  void restoreTask(Task t) {
    tasks.add(t);
    _changed();
  }

  // ---------- Очереди ----------

  /// Возвращает текст ошибки или null.
  String? saveQueue({
    String? id,
    required String key,
    required String name,
    required int colorValue,
  }) {
    final k = key.trim().toUpperCase();
    final n = name.trim();
    if (k.isEmpty || n.isEmpty) return 'Заполните ключ и название';
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(k)) {
      return 'Ключ - только латинские буквы и цифры';
    }
    for (final q in queues) {
      if (q.id != id && q.key == k) return 'Очередь с таким ключом уже есть';
    }
    if (id == null) {
      queues.add(
        TaskQueue(id: newId(), key: k, name: n, colorValue: colorValue),
      );
    } else {
      final q = queueById(id)!;
      q.key = k;
      q.name = n;
      q.colorValue = colorValue;
    }
    _changed();
    return null;
  }

  void deleteQueue(TaskQueue q) {
    if (queues.length <= 1) return;
    tasks.removeWhere((t) => t.queueId == q.id);
    queues.removeWhere((x) => x.id == q.id);
    if (filterQueueId == q.id) filterQueueId = null;
    _changed();
  }

  // ---------- Исполнители ----------

  void addPerson(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    people.add(Person(id: newId(), name: n));
    _changed();
  }

  void renamePerson(Person p, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    p.name = n;
    _changed();
  }

  void deletePerson(Person p) {
    for (final t in tasks) {
      if (t.assigneeId == p.id) t.assigneeId = null;
    }
    people.removeWhere((x) => x.id == p.id);
    if (filterPersonId == p.id) filterPersonId = null;
    _changed();
  }
}

/// Простой InheritedNotifier, чтобы не тянуть сторонние пакеты состояния.
class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({
    super.key,
    required Store store,
    required super.child,
  }) : super(notifier: store);

  static Store of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope not found');
    return scope!.notifier!;
  }
}
