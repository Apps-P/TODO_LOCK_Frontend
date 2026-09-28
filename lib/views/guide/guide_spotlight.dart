import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A spotlight that follows the actual widget, including scrolling/keyboard
/// changes. Only the highlighted control and the guide card receive taps.
class GuideSpotlight extends StatefulWidget {
  final Widget child;
  final GlobalKey targetKey;
  final int step;
  final String title;
  final String description;
  final String nextLabel;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;
  final bool interactive;

  const GuideSpotlight({
    super.key,
    required this.child,
    required this.targetKey,
    required this.step,
    required this.title,
    required this.description,
    required this.nextLabel,
    required this.onNext,
    required this.onSkip,
    this.onBack,
    this.interactive = false,
  });

  @override
  State<GuideSpotlight> createState() => _GuideSpotlightState();
}

class _GuideSpotlightState extends State<GuideSpotlight>
    with WidgetsBindingObserver {
  final _stackKey = GlobalKey();
  Rect? _target;
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _scheduleMeasurement();

  @override
  void didUpdateWidget(covariant GuideSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey) _target = null;
  }

  void _scheduleMeasurement() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      final target = widget.targetKey.currentContext?.findRenderObject();
      final stack = _stackKey.currentContext?.findRenderObject();
      if (target is! RenderBox || stack is! RenderBox || !target.hasSize) {
        return;
      }
      final origin = target.localToGlobal(Offset.zero, ancestor: stack);
      final bounds = (origin & target.size).inflate(6);
      final rect = Rect.fromLTRB(
        bounds.left.clamp(0, stack.size.width),
        bounds.top.clamp(0, stack.size.height),
        bounds.right.clamp(0, stack.size.width),
        bounds.bottom.clamp(0, stack.size.height),
      );
      if (_target != rect) setState(() => _target = rect);
    });
  }

  Widget _barrier(Rect rect) => Positioned.fromRect(
    rect: rect,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: const SizedBox.expand(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    _scheduleMeasurement();
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _scheduleMeasurement();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final media = MediaQuery.of(context);
          final target = _target;
          final top = media.padding.top + 12;
          final bottom =
              size.height -
              math.max(media.viewInsets.bottom, media.padding.bottom) -
              12;
          final above = target == null
              ? 0.0
              : math.max(0.0, target.top - top - 28);
          final below = target == null
              ? 0.0
              : math.max(0.0, bottom - target.bottom - 28);
          final cardAbove = above > below;
          final cardSpace = math.max(above, below);
          final cardEdge = target == null
              ? top
              : cardAbove
              ? target.top - 28
              : target.bottom + 28;

          return Stack(
            key: _stackKey,
            fit: StackFit.expand,
            children: [
              // Screen readers follow the explanation while background actions
              // remain unavailable. The input step exposes its real form.
              ExcludeSemantics(
                excluding: !widget.interactive,
                child: widget.child,
              ),
              if (target == null)
                const ModalBarrier(color: Color(0xB8000000), dismissible: false)
              else ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SpotlightPainter(
                        target: target,
                        cardAbove: cardAbove,
                        cardEdge: cardEdge,
                      ),
                    ),
                  ),
                ),
                _barrier(Rect.fromLTRB(0, 0, size.width, target.top)),
                _barrier(
                  Rect.fromLTRB(0, target.bottom, size.width, size.height),
                ),
                _barrier(
                  Rect.fromLTRB(0, target.top, target.left, target.bottom),
                ),
                _barrier(
                  Rect.fromLTRB(
                    target.right,
                    target.top,
                    size.width,
                    target.bottom,
                  ),
                ),
                if (!widget.interactive) _barrier(target),
                Positioned(
                  left: 20,
                  right: 20,
                  top: cardAbove ? null : cardEdge,
                  bottom: cardAbove ? size.height - cardEdge : null,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: cardSpace),
                    child: Material(
                      color: Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Semantics(
                          container: true,
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '사용 가이드  ${widget.step} / 4',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onSkip,
                                    child: const Text('건너뛰기'),
                                  ),
                                ],
                              ),
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (widget.onBack != null)
                                    TextButton(
                                      onPressed: widget.onBack,
                                      child: const Text('이전'),
                                    ),
                                  const Spacer(),
                                  Flexible(
                                    flex: 4,
                                    child: FilledButton(
                                      key: const ValueKey('guide-next'),
                                      onPressed: widget.onNext,
                                      child: Text(
                                        widget.nextLabel,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect target;
  final bool cardAbove;
  final double cardEdge;

  const _SpotlightPainter({
    required this.target,
    required this.cardAbove,
    required this.cardEdge,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(target, const Radius.circular(14));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rounded);
    canvas.drawPath(mask, Paint()..color = const Color(0xB8000000));
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final start = Offset(
      target.center.dx,
      cardAbove ? target.top : target.bottom,
    );
    final end = Offset(target.center.dx.clamp(40, size.width - 40), cardEdge);
    final connector = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final metric in connector.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 9) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 4, metric.length)),
          paint,
        );
      }
    }
    canvas.drawCircle(start, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      target != oldDelegate.target ||
      cardAbove != oldDelegate.cardAbove ||
      cardEdge != oldDelegate.cardEdge;
}
