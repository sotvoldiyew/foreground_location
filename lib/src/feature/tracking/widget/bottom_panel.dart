import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/tracking_bloc.dart';

class BottomPanel extends StatelessWidget {
  final TrackingState state;
  const BottomPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).padding.bottom;
    final cur = state.currentPoint;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset:     const Offset(0, -6),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 42, height: 4,
          decoration: BoxDecoration(
            color:        Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, 10, 18, bot + 12),
          child: Column(children: [

            Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state.isActive ? Colors.green : Colors.grey.shade400,
                  boxShadow: state.isActive
                      ? [BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 8, spreadRadius: 2,
                  )]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.isActive    ? 'Kuzatilmoqda'
                    : state.isLoading ? 'Yuklanmoqda...'
                    : 'To\'xtatilgan',
                style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color: state.isActive
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.points.length} nuqta',
                  style: TextStyle(
                    fontSize:   12,
                    color:      Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 14),

            if (cur != null) ...[
              Row(children: [
                _InfoTile(
                  icon:  Icons.location_on_rounded,
                  color: Colors.blue,
                  label: 'Koordinat',
                  value: '${cur.latitude.toStringAsFixed(5)}\n'
                      '${cur.longitude.toStringAsFixed(5)}',
                ),
                const SizedBox(width: 8),
                _InfoTile(
                  icon:  Icons.speed_rounded,
                  color: Colors.orange,
                  label: 'Tezlik',
                  value: '${cur.speedKmh.toStringAsFixed(1)}\nkm/h',
                ),
                const SizedBox(width: 8),
                _InfoTile(
                  icon:  Icons.explore_rounded,
                  color: Colors.purple,
                  label: 'Yo\'nalish',
                  value: cur.headingLabel,
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.radar_rounded, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  '±${cur.accuracy.toStringAsFixed(0)} m aniqlik',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  '${cur.timestamp.hour.toString().padLeft(2, '0')}:'
                      '${cur.timestamp.minute.toString().padLeft(2, '0')}:'
                      '${cur.timestamp.second.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ]),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'GPS aniqlanmoqda...',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: _MainButton(state: state)),
              const SizedBox(width: 8),
              _ClearButton(hasPoints: state.points.isNotEmpty),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;
  const _InfoTile({
    required this.icon, required this.color,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(
            fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(
            fontSize: 12, color: color.withOpacity(0.9),
            fontWeight: FontWeight.bold, height: 1.3,
          )),
        ]),
      ),
    );
  }
}

class _MainButton extends StatefulWidget {
  final TrackingState state;
  const _MainButton({required this.state});

  @override
  State<_MainButton> createState() => _MainButtonState();
}

class _MainButtonState extends State<_MainButton> {
  bool _tapping = false;

  Future<void> _onTap() async {
    if (_tapping) return;
    setState(() => _tapping = true);

    final bloc = context.read<TrackingBloc>();
    if (widget.state.isActive) {
      bloc.add(const TrackingStopRequested());
    } else {
      bloc.add(const TrackingStartRequested());
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _tapping = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.isLoading) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          color:        Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _tapping ? null : _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.state.isActive
                ? [Colors.red.shade400, Colors.red.shade700]
                : [const Color(0xFF1976D2), const Color(0xFF0D47A1)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (widget.state.isActive
                  ? Colors.red
                  : const Color(0xFF1565C0))
                  .withOpacity(_tapping ? 0.2 : 0.4),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _tapping ? 0.6 : 1.0,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              widget.state.isActive
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_fill_rounded,
              color: Colors.white, size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              widget.state.isActive ? 'To\'xtatish' : 'Boshlash',
              style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final bool hasPoints;
  const _ClearButton({required this.hasPoints});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: hasPoints ? () => _confirm(context) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: hasPoints ? Colors.red.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_sweep_rounded,
          color: hasPoints ? Colors.red.shade400 : Colors.grey.shade300,
          size: 26,
        ),
      ),
    );
  }

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        title:   const Text('Marshrutni tozalash'),
        content: const Text('Barcha yozilgan nuqtalar o\'chiriladi. Davom etasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TrackingBloc>().add(const TrackingCleared());
            },
            child: Text('O\'chirish',
                style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
  }
}