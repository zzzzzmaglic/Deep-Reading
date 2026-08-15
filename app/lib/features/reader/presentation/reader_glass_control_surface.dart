import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ReaderGlassAction { back, summary, style, standaloneNote }

class ReaderGlassControlSurface extends StatefulWidget {
  const ReaderGlassControlSurface({
    required this.controlsVisible,
    required this.onBack,
    required this.onSummary,
    required this.onStandaloneNote,
    super.key,
  });

  final bool controlsVisible;
  final VoidCallback onBack;
  final VoidCallback onSummary;
  final VoidCallback onStandaloneNote;

  @override
  State<ReaderGlassControlSurface> createState() =>
      _ReaderGlassControlSurfaceState();
}

class _ReaderGlassControlSurfaceState extends State<ReaderGlassControlSurface> {
  static const _channel = MethodChannel('deep-reading/reader-glass-control');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeAction);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _handleNativeAction(MethodCall call) async {
    if (call.method != 'action') {
      return;
    }
    switch (call.arguments) {
      case 'back':
        widget.onBack();
      case 'summary':
        widget.onSummary();
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        key: const Key('reader-glass-ai'),
        right: 20,
        bottom: 28,
        width: 44,
        height: 44,
        child: Semantics(
          button: true,
          enabled: false,
          label: 'AI 伴读',
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _NativeGlassControl(kind: 'aiBackground'),
                const Center(
                  child: Text(
                    '● ●',
                    style: TextStyle(
                      color: Color(0xff1d1d1f),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      IgnorePointer(
        ignoring: !widget.controlsVisible,
        child: AnimatedOpacity(
          key: const Key('reader-controls'),
          duration: const Duration(milliseconds: 180),
          opacity: widget.controlsVisible ? 1 : 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                key: const Key('reader-glass-back'),
                left: 20,
                top: 52,
                width: 44,
                height: 44,
                child: const _NativeGlassControl(kind: 'back'),
              ),
              Positioned(
                key: const Key('reader-glass-summary'),
                right: 20,
                top: 52,
                width: 44,
                height: 44,
                child: const _NativeGlassControl(kind: 'summary'),
              ),
              Positioned(
                key: const Key('reader-glass-tools'),
                left: 22,
                bottom: 28,
                width: 119,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const IgnorePointer(
                      child: _NativeGlassControl(kind: 'toolsBackground'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            container: true,
                            button: true,
                            enabled: false,
                            label: '阅读器样式设置',
                            child: const IgnorePointer(
                              child: Center(
                                child: Text(
                                  'Aa',
                                  style: TextStyle(
                                    color: Color(0xff1d1d1f),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 20, color: Colors.black12),
                        Expanded(
                          child: _ReaderControlBounce(
                            label: '添加独立型笔记',
                            onTap: widget.onStandaloneNote,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/reader_standalone_note.svg',
                                width: 16,
                                height: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ReaderControlBounce extends StatefulWidget {
  const _ReaderControlBounce({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_ReaderControlBounce> createState() => _ReaderControlBounceState();
}

class _ReaderControlBounceState extends State<_ReaderControlBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 180),
    vsync: this,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: .92), weight: 30),
    TweenSequenceItem(tween: Tween<double>(begin: .92, end: 1.06), weight: 40),
    TweenSequenceItem(tween: Tween<double>(begin: 1.06, end: 1), weight: 30),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    child: InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    ),
  );
}

class _NativeGlassControl extends StatelessWidget {
  const _NativeGlassControl({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'deep-reading/reader-glass-control',
        layoutDirection: TextDirection.ltr,
        creationParams: {'kind': kind},
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .56),
        border: Border.all(color: Colors.white.withValues(alpha: .72)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: switch (kind) {
        'back' => const Icon(Icons.arrow_back_ios_new, size: 20),
        'summary' => const Icon(Icons.more_horiz, size: 24),
        _ => const SizedBox.expand(),
      },
    );
  }
}
