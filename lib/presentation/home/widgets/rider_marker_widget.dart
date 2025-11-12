import 'package:flutter/material.dart';

class RiderMarkerWidget extends StatefulWidget {
  final double size;
  final Color color;

  const RiderMarkerWidget({
    super.key,
    this.size = 80,
    this.color = const Color(0xFF0066FF),
  });

  @override
  State<RiderMarkerWidget> createState() => _RiderMarkerWidgetState();
}

class _RiderMarkerWidgetState extends State<RiderMarkerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Efecto de pulso exterior (más lento)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size * _pulseAnimation.value * 0.8,
                height: widget.size * _pulseAnimation.value * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.1),
                ),
              );
            },
          ),

          // Efecto de pulso medio
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size * (1.2 - _pulseAnimation.value * 0.2) * 0.6,
                height: widget.size * (1.2 - _pulseAnimation.value * 0.2) * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.2),
                ),
              );
            },
          ),

          // Círculo principal con gradiente
          Container(
            width: widget.size * 0.4,
            height: widget.size * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color,
                  widget.color.withValues(alpha: 0.8),
                ],
                stops: const [0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              // Ícono de bicicleta
              child: Icon(
                Icons.directions_bike,
                color: Colors.white,
                size: widget.size * 0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
