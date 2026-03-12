import 'package:flutter/material.dart';
import '../bloc/tracking_bloc.dart';

class TopStatusBar extends StatelessWidget {
  final TrackingState state;
  const TopStatusBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 10, 20, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.75), Colors.transparent],
          stops:  const [0.5, 1.0],
        ),
      ),
      child: Row(children: [
        const Text(
          'Location Tracker',
          style: TextStyle(
            color:      Colors.white,
            fontSize:   19,
            fontWeight: FontWeight.bold,
            shadows:    [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color:        state.isActive
                ? Colors.green.withOpacity(0.88)
                : Colors.black54,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: state.isActive
                  ? Colors.greenAccent.withOpacity(0.6)
                  : Colors.white24,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _BlinkingDot(active: state.isActive),
            const SizedBox(width: 6),
            Text(
              state.isActive ? 'LIVE' : 'OFF',
              style: const TextStyle(
                color:         Colors.white,
                fontSize:      12,
                fontWeight:    FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final bool active;
  const _BlinkingDot({required this.active});
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: 7, height: 7,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
      );
    }
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7, height: 7,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      ),
    );
  }
}