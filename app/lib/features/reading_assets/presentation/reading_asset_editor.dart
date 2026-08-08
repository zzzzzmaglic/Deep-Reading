import 'package:app/features/reading_assets/presentation/asset_editor_controller.dart';
import 'package:flutter/material.dart';

class ReadingAssetEditor extends StatefulWidget {
  const ReadingAssetEditor({
    required this.controller,
    required this.onOpenTags,
    required this.onSave,
    required this.onDelete,
    super.key,
  });

  final AssetEditorController controller;
  final VoidCallback onOpenTags;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  State<ReadingAssetEditor> createState() => _ReadingAssetEditorState();
}

class _ReadingAssetEditorState extends State<ReadingAssetEditor> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.controller.draft.noteContent,
  );

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          controller: _textController,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '记录你的思考',
            border: OutlineInputBorder(),
          ),
          onChanged: widget.controller.setNoteContent,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: widget.onOpenTags,
              icon: const Icon(Icons.tag),
              label: const Text('标签'),
            ),
            const Spacer(),
            IconButton(
              tooltip: '删除',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
            FilledButton(onPressed: widget.onSave, child: const Text('完成编辑')),
          ],
        ),
      ],
    );
  }
}
