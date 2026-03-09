import 'package:flutter/material.dart';

class SlidingToggle extends StatefulWidget {
  const SlidingToggle({
    super.key,
    this.value = false,
    this.onChanged,
    this.beginColor = const Color(0xFF3A3A5C),
    this.endColor = const Color(0xFF6C63FF),
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color beginColor;
  final Color endColor;

  @override
  State<SlidingToggle> createState() => _SlidingToggleState();
}

class _SlidingToggleState extends State<SlidingToggle>
    with SingleTickerProviderStateMixin {
  bool _isOn = false;
  late AnimationController _ctrl;
  late Animation<double> _slideAnim;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _isOn = widget.value;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _colorAnim = ColorTween(
      begin: widget.beginColor,
      end: widget.endColor,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (_isOn) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(SlidingToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _isOn) {
      setState(() => _isOn = widget.value);
      _isOn ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    final newValue = !_isOn;
    setState(() => _isOn = newValue);
    newValue ? _ctrl.forward() : _ctrl.reverse();
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    const double w = 60, h = 30, thumb = 22;
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: _colorAnim.value,
              borderRadius: BorderRadius.circular(h / 2),
              boxShadow: _isOn
                  ? [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  spreadRadius: 1,
                )
              ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 4 + _slideAnim.value * (w - thumb - 8),
                  child: Container(
                    width: thumb,
                    height: thumb,
                    decoration: BoxDecoration(
                      color: ColorTween(
                        begin: widget.endColor,
                        end: widget.beginColor,
                      ).evaluate(AlwaysStoppedAnimation(_ctrl.value)),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}