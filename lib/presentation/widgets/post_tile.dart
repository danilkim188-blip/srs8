import 'package:flutter/material.dart';

import '../../data/models/post.dart';

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: post.isLocal
            ? const Icon(Icons.edit_note)
            : Text('${post.id}', style: const TextStyle(fontSize: 12)),
      ),
      title: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.body.replaceAll('\n', ' '),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (post.isLocal)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Chip(
                label: const Text('создан локально'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                backgroundColor:
                    Theme.of(context).colorScheme.tertiaryContainer,
              ),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
