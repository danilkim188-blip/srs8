import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../state/create_post_controller.dart';
import '../state/post_list_controller.dart';
import '../state/users_controller.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => CreatePostController(ctx.read<PostRepository>()),
      child: const _CreatePostForm(),
    );
  }
}

class _CreatePostForm extends StatefulWidget {
  const _CreatePostForm();

  @override
  State<_CreatePostForm> createState() => _CreatePostFormState();
}

class _CreatePostFormState extends State<_CreatePostForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _userId;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Валидация до отправки.
    if (!_formKey.currentState!.validate()) return;
    final create = context.read<CreatePostController>();
    final list = context.read<PostListController>();
    final messenger = ScaffoldMessenger.of(context);

    final serverPost = await create.submit(
      title: _title.text,
      body: _body.text,
      userId: _userId!,
    );
    if (serverPost != null) {
      await list.addLocalPost(serverPost);
      messenger.showSnackBar(const SnackBar(
        content: Text('Пост отправлен и добавлен в список как «создан локально»'),
      ));
    } else if (create.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(create.error!.userMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final create = context.watch<CreatePostController>();
    final users = context.watch<UsersController>();
    final labels = users.labels;

    return Scaffold(
      appBar: AppBar(title: const Text('Новый пост')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _title,
                  enabled: !create.submitting,
                  decoration: const InputDecoration(
                    labelText: 'Заголовок (5–100 символов)',
                    border: OutlineInputBorder(),
                  ),
                  validator: PostValidators.title,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _body,
                  enabled: !create.submitting,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Текст (10–1000 символов)',
                    border: OutlineInputBorder(),
                  ),
                  validator: PostValidators.body,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _userId,
                  decoration: InputDecoration(
                    labelText: 'Автор',
                    border: const OutlineInputBorder(),
                    helperText: users.loading
                        ? 'Загружаем авторов…'
                        : users.error != null
                            ? 'Список авторов не загрузился, показан запасной'
                            : null,
                  ),
                  items: [
                    for (final e in labels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged:
                      create.submitting ? null : (v) => setState(() => _userId = v),
                  validator: PostValidators.user,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    // Кнопка заблокирована, пока идёт запрос.
                    onPressed: create.submitting ? null : _submit,
                    icon: create.submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(create.submitting ? 'Отправка…' : 'Отправить'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (create.status == SubmitStatus.failure)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(create.error!.userMessage),
              ),
            ),
          if (create.status == SubmitStatus.success && create.serverPost != null)
            _ServerResponseCard(post: create.serverPost!),
        ],
      ),
    );
  }
}

class _ServerResponseCard extends StatelessWidget {
  const _ServerResponseCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ответ сервера', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('id: ${post.id}'),
            Text('userId: ${post.userId}'),
            Text('title: ${post.title}'),
            Text('body: ${post.body}'),
            const SizedBox(height: 8),
            const Text(
              'JSONPlaceholder не сохраняет данные: в списке пост показан '
              'с пометкой «создан локально».',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
