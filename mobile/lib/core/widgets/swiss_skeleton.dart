import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SwissSkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SwissSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppTheme.radiusSm,
    this.margin,
  });

  @override
  State<SwissSkeletonBox> createState() => _SwissSkeletonBoxState();
}

class _SwissSkeletonBoxState extends State<SwissSkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: AppTheme.beige.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: AppTheme.border.withValues(alpha: _animation.value),
              width: 1.0,
            ),
          ),
        );
      },
    );
  }
}

class SwissSkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;

  const SwissSkeletonCard({
    super.key,
    this.height = 100,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    return SwissSkeletonBox(
      height: height,
      margin: margin,
    );
  }
}

class SwissSkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SwissSkeletonList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => SwissSkeletonBox(
          height: itemHeight,
          margin: const EdgeInsets.only(bottom: 8),
        ),
      ),
    );
  }
}
