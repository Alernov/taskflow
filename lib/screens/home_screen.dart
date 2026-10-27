import 'package:flutter/material.dart';

import '../store.dart';
import '../widgets.dart';
import 'board_tab.dart';
import 'list_tab.dart';
import 'manage_tab.dart';
import 'task_editor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  static const _titles = ['Список', 'Доска', 'Управление'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch(Store store) {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchCtrl.clear();
      store.setSearch('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final onTasksTab = _tab < 2;

    return Scaffold(
      appBar: AppBar(
        title: _searching && onTasksTab
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск по задачам',
                  border: InputBorder.none,
                ),
                onChanged: store.setSearch,
              )
            : Text(_titles[_tab]),
        actions: [
          if (onTasksTab)
            IconButton(
              tooltip: 'Поиск',
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => _toggleSearch(store),
            ),
        ],
      ),
      body: Column(
        children: [
          if (onTasksTab) const FilterBar(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                ListTab(),
                BoardTab(),
                ManageTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: onTasksTab
          ? FloatingActionButton(
              onPressed: () => openTaskEditor(
                context,
                newTaskDraft(store),
                isNew: true,
              ),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl),
            label: 'Список',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban),
            label: 'Доска',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            label: 'Управление',
          ),
        ],
      ),
    );
  }
}
