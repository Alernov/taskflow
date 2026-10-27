import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'task_editor.dart';

/// Вкладка «Доска» - канбан по статусам. Карточки перетаскиваются долгим нажатием.
class BoardTab extends StatefulWidget {
  const BoardTab({super.key});

  @override
  State<BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<BoardTab> {
  final _scroll = ScrollController();
  Timer? _timer;
  double _dragX = 0;

  @override
  void dispose() {
    _stopAutoScroll();
    _scroll.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _stopAutoScroll() {
    _timer?.cancel();
    _timer = null;
  }

  /// Подскролл доски, когда карточку тянут к краю экрана.
  void _tick() {
    if (!mounted || !_scroll.hasClients) return;
    final width = MediaQuery.of(context).size.width;
    const edge = 56.0;
    double delta = 0;
    if (_dragX < edge) {
      delta = -10;
    } else if (_dragX > width - edge) {
      delta = 10;
    }
    if (delta == 0) return;
    final max = _scroll.position.maxScrollExtent;
    final target = (_scroll.offset + delta).clamp(0.0, max).toDouble();
    _scroll.jumpTo(target);
  }

  Widget _cardBody(Store store, Task t, {bool dragging = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: dragging ? 6 : 0,
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: dragging
            ? null
            : () => openTaskEditor(context, t.copy(), isNew: false),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: t.priority.color, width: 4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 6),
              TaskMeta(task: t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Store store, Task t, double colWidth) {
    return LongPressDraggable<Task>(
      data: t,
      onDragStarted: () {
        _dragX = MediaQuery.of(context).size.width / 2;
        _startAutoScroll();
      },
      onDragUpdate: (d) => _dragX = d.globalPosition.dx,
      onDragEnd: (_) => _stopAutoScroll(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: colWidth - 24,
          child: Opacity(
            opacity: 0.92,
            child: _cardBody(store, t, dragging: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _cardBody(store, t),
      ),
      child: _cardBody(store, t),
    );
  }

  Widget _column(
    Store store,
    TaskStatus status,
    List<Task> tasks,
    double colWidth,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: colWidth,
      child: DragTarget<Task>(
        onWillAcceptWithDetails: (d) => d.data.status != status,
        onAcceptWithDetails: (d) {
          _stopAutoScroll();
          store.setStatus(d.data, status);
        },
        builder: (context, candidates, rejected) {
          final hover = candidates.isNotEmpty;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: hover
                  ? status.color.withAlpha(45)
                  : scheme.secondaryContainer.withAlpha(70),
              borderRadius: BorderRadius.circular(16),
              border: hover ? Border.all(color: status.color, width: 2) : null,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    children: [
                      Icon(status.icon, size: 20, color: status.color),
                      const SizedBox(width: 8),
                      Text(
                        status.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${tasks.length}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Text(
                            'Пусто',
                            style: TextStyle(color: scheme.outline),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 88),
                          children: [
                            for (final t in tasks)
                              KeyedSubtree(
                                key: ValueKey('card_${t.id}'),
                                child: _card(store, t, colWidth),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.visibleTasks;
    final width = MediaQuery.of(context).size.width;
    final colWidth = (width * 0.82).clamp(260.0, 340.0).toDouble();

    return ListView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      children: [
        for (final s in TaskStatus.values)
          _column(
            store,
            s,
            all.where((t) => t.status == s).toList(),
            colWidth,
          ),
      ],
    );
  }
}
