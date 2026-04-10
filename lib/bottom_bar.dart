import 'package:flutter/material.dart';

class BottomBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  const BottomBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

class CustomBottomBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomBarItem> items;

  final Color? barColor;

  final Color accentColor;

  final double height;

  final double accentLineHeight;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.barColor,
    this.accentColor = const Color(0xFFF59E0B),
    this.height = 64.0,
    this.accentLineHeight = 3.0,
  });

  @override
  State<CustomBottomBar> createState() => _CustomBottomBarState();
}

class _CustomBottomBarState extends State<CustomBottomBar>
    with TickerProviderStateMixin {

  late List<AnimationController> _controllers;
  late List<Animation<double>> _lineWidthAnims;
  late List<Animation<double>> _scaleAnims;
  late List<Animation<double>> _labelAnims;

  @override
  void initState() {
    super.initState();
    _buildAnimations();
    // Instantly activate the initial tab
    _controllers[widget.currentIndex].value = 1.0;
  }

  void _buildAnimations() {
    _controllers = List.generate(
      widget.items.length,
          (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
      ),
    );

    _lineWidthAnims = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutCubic))
        .toList();

    _scaleAnims = _controllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutBack),
      );
    }).toList();

    _labelAnims = _controllers.map((c) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutCubic),
      );
    }).toList();
  }

  @override
  void didUpdateWidget(covariant CustomBottomBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _controllers[old.currentIndex].reverse();
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final resolvedBarColor =
        widget.barColor ?? theme.bottomNavigationBarTheme.backgroundColor ?? Colors.white;

    return Container(
      height: widget.height + bottomPadding,
      decoration: BoxDecoration(
        color: resolvedBarColor,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
          children: List.generate(widget.items.length, (i) {
            return Expanded(
              child: _BarTab(
                item: widget.items[i],
                isSelected: widget.currentIndex == i,
                accentColor: widget.accentColor,
                accentLineHeight: widget.accentLineHeight,
                lineAnim: _lineWidthAnims[i],
                scaleAnim: _scaleAnims[i],
                labelAnim: _labelAnims[i],
                onTap: () => widget.onTap(i),
              ),
            );
          }),
        ),
      ),
    );
  }
}
class _BarTab extends StatelessWidget {
  final BottomBarItem item;
  final bool isSelected;
  final Color accentColor;
  final double accentLineHeight;
  final Animation<double> lineAnim;
  final Animation<double> scaleAnim;
  final Animation<double> labelAnim;
  final VoidCallback onTap;

  const _BarTab({
    required this.item,
    required this.isSelected,
    required this.accentColor,
    required this.accentLineHeight,
    required this.lineAnim,
    required this.scaleAnim,
    required this.labelAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Colors.blueGrey.shade300;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([lineAnim, scaleAnim, labelAnim]),
        builder: (context, _) {
          final lineProgress = lineAnim.value;
          final labelOpacity = labelAnim.value;

          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final maxW = constraints.maxWidth * 0.55;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      width: maxW * lineProgress,
                      height: accentLineHeight,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(accentLineHeight),
                          bottomRight: Radius.circular(accentLineHeight),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.scale(
                    scale: scaleAnim.value,
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 24,
                      color: isSelected ? accentColor : inactiveColor,
                    ),
                  ),
                  if (item.badgeCount > 0)
                    Positioned(
                      top: -5,
                      right: -8,
                      child: _Badge(count: item.badgeCount),
                    ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: Color.lerp(inactiveColor, accentColor, labelOpacity),
                  letterSpacing: isSelected ? 0.3 : 0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }
}


class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}