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
          onPressed: () => onAction(ReaderContextAction.highlight),
        ),
        ContextMenuButtonItem(
          label: '打开阅读资产卡片',
          onPressed: () => onAction(ReaderContextAction.openAssetCard),
        ),
        ContextMenuButtonItem(
          label: 'AI释义',
          onPressed: () => onAction(ReaderContextAction.explainWithAi),
        ),
        ContextMenuButtonItem(
          label: '拷贝',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: selection.selectedText));
            onAction(ReaderContextAction.copy);
          },
        ),
      ],
    );
  }
}
