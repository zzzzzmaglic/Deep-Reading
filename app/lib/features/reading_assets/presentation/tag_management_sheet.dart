import 'package:app/features/reading_assets/domain/reading_asset.dart';
import 'package:flutter/material.dart';

class TagManagementSheet extends StatefulWidget {
  const TagManagementSheet({
    required this.tags,
    required this.selectedTagIds,
    required this.lockedTagIds,
    required this.onConfirm,
    this.onCreateTag,
    super.key,
  });

  final List<Tag> tags;
  final Set<String> selectedTagIds;
  final Set<String> lockedTagIds;
  final ValueChanged<Set<String>> onConfirm;
  final Future<Tag> Function(String name)? onCreateTag;

  @override
  State<TagManagementSheet> createState() => _TagManagementSheetState();
}

class _TagManagementSheetState extends State<TagManagementSheet> {
  late final Set<String> _selected = {...widget.selectedTagIds};
  late final List<Tag> _tags = [...widget.tags];
  bool _creating = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: _creating ? _buildCreateView(context) : _buildTagView(context),
      ),
    );
  }

  Widget _buildTagView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '管理标签',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => widget.onConfirm(Set.unmodifiable(_selected)),
              child: const Text('完成'),
            ),
          ],
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final tag in _tags)
                CheckboxListTile(
                  value: _selected.contains(tag.id),
                  title: Text(tag.name),
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: widget.lockedTagIds.contains(tag.id)
                      ? null
                      : (value) {
                          setState(() {
                            if (value ?? false) {
                              _selected.add(tag.id);
                            } else {
                              _selected.remove(tag.id);
                            }
                          });
                        },
                ),
              if (widget.onCreateTag != null)
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('＋ 新建标签'),
                  onTap: () => setState(() => _creating = true),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '返回',
              onPressed: () => setState(() => _creating = false),
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
              child: Text(
                '新建标签',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: _createTag, child: const Text('完成')),
          ],
        ),
        TextField(
          autofocus: true,
          controller: _nameController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _createTag(),
          decoration: const InputDecoration(labelText: '标签名称'),
        ),
      ],
    );
  }

  Future<void> _createTag() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || widget.onCreateTag == null) return;
    final tag = await widget.onCreateTag!(name);
    if (!mounted) return;
    setState(() {
      _tags.add(tag);
      _selected.add(tag.id);
      _nameController.clear();
      _creating = false;
    });
  }
}
