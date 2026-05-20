import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:school_attendance/features/students/repository/student_repository.dart';

class StudentSwipeCard extends StatelessWidget {
  const StudentSwipeCard({
    super.key,
    required this.student,
    required this.swipeDirection,
  });

  final StudentModel student;
  final CardSwiperDirection? swipeDirection;

  Color? get _overlayColor {
    if (swipeDirection == null) return null;
    if (swipeDirection!.isCloseTo(CardSwiperDirection.left)) {
      return Colors.green.withValues(alpha: 0.7);
    }
    if (swipeDirection!.isCloseTo(CardSwiperDirection.right)) {
      return Colors.red.withValues(alpha: 0.7);
    }
    if (swipeDirection!.isCloseTo(CardSwiperDirection.top)) {
      return Colors.amber.withValues(alpha: 0.7);
    }
    return null;
  }

  IconData? get _overlayIcon {
    if (swipeDirection == null) return null;
    if (swipeDirection!.isCloseTo(CardSwiperDirection.left)) {
      return Icons.check_circle_outline;
    }
    if (swipeDirection!.isCloseTo(CardSwiperDirection.right)) {
      return Icons.cancel_outlined;
    }
    if (swipeDirection!.isCloseTo(CardSwiperDirection.top)) {
      return Icons.event_busy_outlined;
    }
    return null;
  }

  String? get _overlayLabel {
    if (swipeDirection == null) return null;
    if (swipeDirection!.isCloseTo(CardSwiperDirection.left)) return 'PRESENT';
    if (swipeDirection!.isCloseTo(CardSwiperDirection.right)) return 'ABSENT';
    if (swipeDirection!.isCloseTo(CardSwiperDirection.top)) return 'LEAVE';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final overlayColor = _overlayColor;
    final overlayIcon = _overlayIcon;
    final overlayLabel = _overlayLabel;

    return Stack(
      children: [
        Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surfaceContainerLow,
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage: (student.photoUrl != null &&
                          student.photoUrl!.isNotEmpty)
                      ? NetworkImage(student.photoUrl!)
                      : null,
                  child: (student.photoUrl == null || student.photoUrl!.isEmpty)
                      ? Text(
                          student.fullName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  student.fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Roll #${student.rollNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 32),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SwipeHint(
                        icon: Icons.arrow_back,
                        label: 'Present',
                        color: Colors.green),
                    _SwipeHint(
                        icon: Icons.arrow_upward,
                        label: 'Leave',
                        color: Colors.amber),
                    _SwipeHint(
                        icon: Icons.arrow_forward,
                        label: 'Absent',
                        color: Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (overlayColor != null)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: overlayColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(overlayIcon, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    overlayLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
