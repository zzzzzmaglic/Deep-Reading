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
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  bool _creating = false;
  bool _submitting = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          children: [
            const Text(
              '管理标签',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final tag in _tags)
                    CheckboxListTile(
                      value: _selected.contains(tag.id),
                      title: Text(tag.name),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: widget.lockedTagIds.contains(tag.id)
                          ? null
                          : (value) => setState(() {
                              if (value ?? false) {
                                _selected.add(tag.id);
                              } else {
                                _selected.remove(tag.id);
                              }
                            }),
                    ),
                  _creating
                      ? _createRow()
                      : ListTile(
                          leading: const Icon(Icons.add),
                          title: const Text('＋ 新建标签'),
                          onTap: () {
                            setState(() {
                              _creating = true;
                              _error = null;
                            });
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _nameFocus.requestFocus(),
                            );
                          },
                        ),
                ],
              ),
            ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Divider(),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => widget.onConfirm(Set.unmodifiable(_selected)),
                  child: const Text('完成'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget _createRow() => Row(
    children: [
      Expanded(
        child: TextField(
          key: const ValueKey('new-tag-input'),
          focusNode: _nameFocus,
          controller: _name,
          decoration: const InputDecoration(hintText: '新建标签'),
          onSubmitted: (_) => _create(),
        ),
      ),
      IconButton(
        tooltip: '创建标签',
        onPressed: _submitting ? null : _create,
        icon: _submitting
            ? const CircularProgressIndicator()
            : const Icon(Icons.check),
      ),
    ],
  );
  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入标签名称');
      return;
    }
    if (name.length > 48) {
      setState(() => _error = '标签名称最多 48 个字符');
      return;
    }
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(name)) {
      setState(() => _error = '标签名称不能包含控制字符');
      return;
    }
    if (widget.onCreateTag == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final tag = await widget.onCreateTag!(name);
      if (!mounted) return;
      setState(() {
        _tags.add(tag);
        _selected.add(tag.id);
        _name.clear();
        _creating = false;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error.toString().contains('exists') ||
                  error.toString().contains('23505')
              ? '标签已存在'
              : '无法创建标签',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
