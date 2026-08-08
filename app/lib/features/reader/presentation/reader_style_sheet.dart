import 'package:flutter/material.dart';

enum ReaderThemeMode { light, dark, system }

enum ReaderFontSize {
  small(17),
  smaller(19),
  defaultSize(21),
  larger(23),
  large(25);

  const ReaderFontSize(this.points);

  static const medium = defaultSize;
  static const normal = defaultSize;
  static const standard = defaultSize;

  final double points;
}

class ReaderStyleSheet extends StatelessWidget {
  const ReaderStyleSheet({
    int? fontIndex,
    int? fontSizeIndex,
    this.onFontIndexChanged,
    this.themeMode = ReaderThemeMode.system,
    this.onThemeModeChanged,
    super.key,
  }) : fontIndex = fontIndex ?? fontSizeIndex ?? ReaderFontSize.defaultSize.index;

  final int fontIndex;
  final ValueChanged<int>? onFontIndexChanged;
  final ReaderThemeMode themeMode;
  final ValueChanged<ReaderThemeMode>? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final boundedIndex =
        fontIndex.clamp(0, ReaderFontSize.values.length - 1) as int;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        children: [
          const Text('字号', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                key: const Key('decrease-font'),
                tooltip: '减小字号',
                onPressed: boundedIndex == 0
                    ? null
                    : () => onFontIndexChanged?.call(boundedIndex - 1),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${ReaderFontSize.values[boundedIndex].points.toInt()} pt',
                  ),
                ),
              ),
              IconButton(
                key: const Key('increase-font'),
                tooltip: '增大字号',
                onPressed: boundedIndex == ReaderFontSize.values.length - 1
                    ? null
                    : () => onFontIndexChanged?.call(boundedIndex + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const Divider(height: 20),
          const Text('主题', style: TextStyle(fontWeight: FontWeight.w600)),
          for (final mode in ReaderThemeMode.values)
            RadioListTile<ReaderThemeMode>(
              contentPadding: EdgeInsets.zero,
              title: Text(_themeLabel(mode)),
              value: mode,
              groupValue: themeMode,
              onChanged: (value) {
                if (value != null) {
                  onThemeModeChanged?.call(value);
                }
              },
            ),
        ],
      ),
    );
  }

  String _themeLabel(ReaderThemeMode mode) {
    return switch (mode) {
      ReaderThemeMode.light => '浅色',
      ReaderThemeMode.dark => '深色',
      ReaderThemeMode.system => '跟随系统',
    };
  }
}
