import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reader_selection_adapter.dart';

enum ReaderContextAction { highlight, openAssetCard, explainWithAi, copy }

class ReaderContextMenu extends StatelessWidget {
  const ReaderContextMenu({
    required this.selection,
    required this.anchors,
    required this.onAction,
    super.key,
  });

  final ReaderSelection selection;
  final TextSelectionToolbarAnchors anchors;
  final ValueChanged<ReaderContextAction> onAction;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: '划线',
          onPressed: () => _invoke(ReaderContextAction.highlight),
        ),
        ContextMenuButtonItem(
          label: '打开阅读资产卡片',
          onPressed: () => _invoke(ReaderContextAction.openAssetCard),
        ),
        ContextMenuButtonItem(
          label: 'AI释义',
          onPressed: () => _invoke(ReaderContextAction.explainWithAi),
        ),
        ContextMenuButtonItem(
          label: '拷贝',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: selection.selectedText));
            _invoke(ReaderContextAction.copy);
          },
        ),
      ],
    );
  }

  void _invoke(ReaderContextAction action) {
    ContextMenuController.removeAny();
    onAction(action);
  }
}
