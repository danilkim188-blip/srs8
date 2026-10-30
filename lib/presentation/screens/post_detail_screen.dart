import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../state/post_detail_controller.dart';
import '../widgets/error_view.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          PostDetailController(ctx.read<PostRepository>(), post)..load(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PostDetailController>();
    final post = c.post;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(post.isLocal ? 'Пост (локальный)' : 'Пост #${post.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(post.title, style: theme.textTheme.headlineSmall),
          if (post.isLocal)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Chip(label: Text('создан локально — на сервере не хранится')),
            ),
          const SizedBox(height: 12),
          Text(post.body),
          const SizedBox(height: 20),
          _AuthorSection(controller: c),
          const SizedBox(height: 20),
          Text('Комментарии', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _Comments(controller: c),
        ],
      ),
    );
  }
}

class _AuthorSection extends StatelessWidget {
  const _AuthorSection({required this.controller});

  final PostDetailController controller;

  @override
  Widget build(BuildContext context) {
    final a = controller.author;
    final count = controller.authorPostsCount;
    Widget child;
    if (a.loading) {
      child = const LinearProgressIndicator();
    } else if (a.error != null) {
      child = const Text('Не удалось загрузить автора');
    } else {
      final u = a.data!;
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(u.name, style: Theme.of(context).textTheme.titleMedium),
          Text('@${u.username} · ${u.email}'),
          if (u.company != null) Text('Компания: ${u.company!.name}'),
          if (u.address?.city != null) Text('Город: ${u.address!.city}'),
          if (count.data != null) Text('Постов у автора: ${count.data}'),
        ],
      );
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _Comments extends StatelessWidget {
  const _Comments({required this.controller});

  final PostDetailController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.comments;
    if (c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null) {
      return ErrorView(
        message: 'Не удалось загрузить комментарии',
        onRetry: controller.load,
      );
    }
    final list = c.data!;
    if (list.isEmpty) {
      return Text(controller.post.isLocal
          ? 'У локального поста нет комментариев.'
          : 'Комментариев пока нет.');
    }
    return Column(
      children: [
        for (final comment in list)
          Card(
            child: ListTile(
              title: Text(comment.name),
              subtitle: Text('${comment.email}\n${comment.body}'),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }
}
