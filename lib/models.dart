import 'package:flutter/material.dart';

/// Статусы задачи (как рабочие статусы в Яндекс Трекере).
enum TaskStatus { open, inProgress, review, done }

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.open:
        return 'Открыта';
      case TaskStatus.inProgress:
        return 'В работе';
      case TaskStatus.review:
        return 'На проверке';
      case TaskStatus.done:
        return 'Готово';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.open:
        return const Color(0xFF607D8B);
      case TaskStatus.inProgress:
        return const Color(0xFF1E88E5);
      case TaskStatus.review:
        return const Color(0xFFFB8C00);
      case TaskStatus.done:
        return const Color(0xFF43A047);
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.open:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.timelapse;
      case TaskStatus.review:
        return Icons.fact_check_outlined;
      case TaskStatus.done:
        return Icons.check_circle;
    }
  }
}

/// Приоритеты.
enum Priority { urgent, high, normal, low }

extension PriorityX on Priority {
  String get label {
    switch (this) {
      case Priority.urgent:
        return 'Срочный';
      case Priority.high:
        return 'Высокий';
      case Priority.normal:
        return 'Обычный';
      case Priority.low:
        return 'Низкий';
    }
  }

  Color get color {
    switch (this) {
      case Priority.urgent:
        return const Color(0xFFE53935);
      case Priority.high:
        return const Color(0xFFFB8C00);
      case Priority.normal:
        return const Color(0xFF1E88E5);
      case Priority.low:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData get icon {
    switch (this) {
      case Priority.urgent:
        return Icons.keyboard_double_arrow_up;
      case Priority.high:
        return Icons.keyboard_arrow_up;
      case Priority.normal:
        return Icons.drag_handle;
      case Priority.low:
        return Icons.keyboard_arrow_down;
    }
  }

  /// Чем меньше число, тем выше в списке.
  int get rank => index;
}

int _idCounter = 0;

String newId() {
  _idCounter++;
  return '${DateTime.now().microsecondsSinceEpoch}$_idCounter';
}

/// Очередь (как очередь в Трекере): ключ + название + цвет.
class TaskQueue {
  String id;
  String key;
  String name;
  int colorValue;
  int counter;

  TaskQueue({
    required this.id,
    required this.key,
    required this.name,
    required this.colorValue,
    this.counter = 0,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'name': name,
        'color': colorValue,
        'counter': counter,
      };

  factory TaskQueue.fromJson(Map<String, dynamic> j) => TaskQueue(
        id: j['id'] as String,
        key: j['key'] as String,
        name: j['name'] as String,
        colorValue: j['color'] as int,
        counter: (j['counter'] as int?) ?? 0,
      );
}

/// Исполнитель.
class Person {
  String id;
  String name;

  Person({required this.id, required this.name});

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Person.fromJson(Map<String, dynamic> j) =>
      Person(id: j['id'] as String, name: j['name'] as String);
}

/// Подзадача (простой чек-лист как в Google Задачах).
class SubTask {
  String id;
  String title;
  bool done;

  SubTask({required this.id, required this.title, this.done = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  factory SubTask.fromJson(Map<String, dynamic> j) => SubTask(
        id: j['id'] as String,
        title: j['title'] as String,
        done: (j['done'] as bool?) ?? false,
      );
}

class Task {
  String id;
  String queueId;
  int number;
  String title;
  String notes;
  TaskStatus status;
  Priority priority;
  String? assigneeId;
  DateTime? due;
  List<SubTask> subtasks;
  DateTime createdAt;

  Task({
    required this.id,
    required this.queueId,
    required this.number,
    required this.title,
    this.notes = '',
    this.status = TaskStatus.open,
    this.priority = Priority.normal,
    this.assigneeId,
    this.due,
    List<SubTask>? subtasks,
    DateTime? createdAt,
  })  : subtasks = subtasks ?? <SubTask>[],
        createdAt = createdAt ?? DateTime.now();

  bool get isDone => status == TaskStatus.done;

  Task copy() => Task(
        id: id,
        queueId: queueId,
        number: number,
        title: title,
        notes: notes,
        status: status,
        priority: priority,
        assigneeId: assigneeId,
        due: due,
        subtasks: subtasks
            .map((s) => SubTask(id: s.id, title: s.title, done: s.done))
            .toList(),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'queueId': queueId,
        'number': number,
        'title': title,
        'notes': notes,
        'status': status.name,
        'priority': priority.name,
        'assigneeId': assigneeId,
        'due': due?.millisecondsSinceEpoch,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Task.fromJson(Map<String, dynamic> j) {
    final dueMs = j['due'] as int?;
    return Task(
      id: j['id'] as String,
      queueId: j['queueId'] as String,
      number: j['number'] as int,
      title: j['title'] as String,
      notes: (j['notes'] as String?) ?? '',
      status: TaskStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => TaskStatus.open,
      ),
      priority: Priority.values.firstWhere(
        (p) => p.name == j['priority'],
        orElse: () => Priority.normal,
      ),
      assigneeId: j['assigneeId'] as String?,
      due: dueMs == null ? null : DateTime.fromMillisecondsSinceEpoch(dueMs),
      subtasks: ((j['subtasks'] as List?) ?? const [])
          .map((e) => SubTask.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

// ---------- Даты ----------

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const _months = [
  'янв',
  'фев',
  'мар',
  'апр',
  'мая',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];

String formatDue(DateTime d) {
  final today = dateOnly(DateTime.now());
  final diff = dateOnly(d).difference(today).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Завтра';
  if (diff == -1) return 'Вчера';
  final base = '${d.day} ${_months[d.month - 1]}';
  return d.year == today.year ? base : '$base ${d.year}';
}
