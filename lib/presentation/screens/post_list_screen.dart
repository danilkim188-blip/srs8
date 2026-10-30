import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/post_list_controller.dart';
import '../state/users_controller.dart';
import '../widgets/error_view.dart';
import '../widgets/post_tile.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      context.read<PostListController>().loadNextPage();
    }
  }

  /// Если первая страница не заполнила экран, прокрутки не будет —
  /// догружаем следующую страницу сами (только без поискового запроса).
  void _fillViewport(PostListController c) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (c.query.isEmpty && _scroll.position.maxScrollExtent <= 0) {
        c.loadNextPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PostListController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Explorer'),
        actions: [
          IconButton(
            tooltip: c.ascending
                ? 'Сортировка по ID: по возрастанию'
                : 'Сортировка по ID: по убыванию',
            icon: Icon(c.ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: c.toggleSort,
          ),
          IconButton(
            tooltip: 'Сбросить фильтры',
            icon: const Icon(Icons.filter_alt_off),
            onPressed: c.hasFilters
                ? () {
                    _search.clear();
                    c.resetFilters();
                  }
                : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CreatePostScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Создать'),
      ),
      body: Column(
        children: [
          _Filters(controller: c, search: _search),
          if (c.refreshing) const LinearProgressIndicator(minHeight: 2),
          if (c.fromCache) _CacheBanner(controller: c),
          Expanded(child: _Body(controller: c, scroll: _scroll, onBuilt: _fillViewport)),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller, required this.search});

  final PostListController controller;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final labels = context.watch<UsersController>().labels;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: search,
            onChanged: controller.setQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'Поиск по заголовку',
              // Явно показываем область поиска (требование ТЗ).
              helperText: 'Ищем только среди загруженных постов '
                  '(${controller.loadedCount}), а не по всему набору данных',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Автор: '),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: controller.userId,
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Все авторы')),
                    for (final e in labels.entries)
                      DropdownMenuItem<int?>(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: controller.setUserFilter,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CacheBanner extends StatelessWidget {
  const _CacheBanner({required this.controller});

  final PostListController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = controller.refreshing
        ? 'Показаны сохранённые данные. Обновляем…'
        : 'Показаны сохранённые данные. '
            '${controller.error?.userMessage ?? ''}';
    return Container(
      width: double.infinity,
      color: cs.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.history, size: 18, color: cs.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text.trim(),
                style: TextStyle(color: cs.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.scroll,
    required this.onBuilt,
  });

  final PostListController controller;
  final ScrollController scroll;
  final void Function(PostListController) onBuilt;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    switch (c.status) {
      case ListStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ListStatus.error:
        return ErrorView(
          message: c.error?.userMessage ?? 'Не удалось загрузить посты',
          onRetry: c.load,
        );
      case ListStatus.empty:
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Center(child: Text('Постов пока нет')),
            ],
          ),
        );
      case ListStatus.success:
        final items = c.visibleItems;
        onBuilt(c);
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: c.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                const Center(
                    child: Text('Ничего не найдено среди загруженных постов')),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: c.resetFilters,
                    child: const Text('Сбросить фильтры'),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView.separated(
            controller: scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == items.length) return _Footer(controller: c);
              final post = items[i];
              return PostTile(
                post: post,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostDetailScreen(post: post),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final PostListController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.pageStatus) {
      case PageStatus.loading:
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      case PageStatus.error:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                controller.pageError?.userMessage ??
                    'Не удалось загрузить следующую страницу',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.retryNextPage,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        );
      case PageStatus.ended:
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Больше постов нет')),
        );
      case PageStatus.idle:
        return const SizedBox(height: 56);
    }
  }
}
