import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_attendance/features/attendance/notifier/attendance_notifier.dart';
import 'package:school_attendance/features/attendance/repository/attendance_repository.dart';
import 'package:school_attendance/features/attendance/widgets/student_swipe_card.dart';

class AttendanceSwipeScreen extends ConsumerStatefulWidget {
  const AttendanceSwipeScreen({
    super.key,
    required this.classID,
    required this.className,
  });

  final String classID;
  final String className;

  @override
  ConsumerState<AttendanceSwipeScreen> createState() =>
      _AttendanceSwipeScreenState();
}

class _AttendanceSwipeScreenState
    extends ConsumerState<AttendanceSwipeScreen> {
  final _controller = CardSwiperController();
  CardSwiperDirection? _currentDirection;

  @override
  void initState() {
    super.initState();
    // Check after first frame if today's session already submitted → go to stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session =
          ref.read(attendanceNotifierProvider(widget.classID)).valueOrNull;
      if (session?.submittedSession != null) {
        context.pushReplacement('/classes/${widget.classID}/stats',
            extra: {'className': widget.className});
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AttendanceStatus _statusFor(CardSwiperDirection direction) {
    if (direction.isCloseTo(CardSwiperDirection.left)) {
      return AttendanceStatus.present;
    }
    if (direction.isCloseTo(CardSwiperDirection.top)) {
      return AttendanceStatus.leave;
    }
    return AttendanceStatus.absent;
  }

  Future<bool> _onSwipe(
    int prevIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    final session =
        ref.read(attendanceNotifierProvider(widget.classID)).valueOrNull;
    if (session == null) return false;
    if (prevIndex >= session.students.length) return false;

    final student = session.students[prevIndex];
    final status = _statusFor(direction);

    ref
        .read(attendanceNotifierProvider(widget.classID).notifier)
        .mark(student.id, status);

    setState(() => _currentDirection = null);

    // When all cards swiped, navigate to summary
    final updated =
        ref.read(attendanceNotifierProvider(widget.classID)).valueOrNull;
    if (updated != null && updated.allMarked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.push(
            '/classes/${widget.classID}/attendance/summary',
            extra: {'className': widget.className},
          );
        }
      });
    }

    return true;
  }

  void _onSwipeDirectionChange(
    CardSwiperDirection horizontalDirection,
    CardSwiperDirection verticalDirection,
  ) {
    final dominant =
        verticalDirection != CardSwiperDirection.none
            ? verticalDirection
            : horizontalDirection;
    setState(() => _currentDirection = dominant);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(attendanceNotifierProvider(widget.classID));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        actions: [
          TextButton(
            onPressed: () => context.push(
              '/classes/${widget.classID}/attendance/summary',
              extra: {'className': widget.className},
            ),
            child: const Text('Review'),
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (session) {
          if (session.students.isEmpty) {
            return const Center(
              child: Text('No active students in this class'),
            );
          }

          if (session.allMarked) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      size: 80, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'All students marked!',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.push(
                      '/classes/${widget.classID}/attendance/summary',
                      extra: {'className': widget.className},
                    ),
                    icon: const Icon(Icons.summarize),
                    label: const Text('Review & Submit'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              LinearProgressIndicator(
                value: session.students.isEmpty
                    ? 0
                    : session.currentIndex / session.students.length,
                backgroundColor: Colors.grey.shade200,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${session.currentIndex} of ${session.students.length}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CardSwiper(
                    controller: _controller,
                    cardsCount: session.students.length,
                    initialIndex: session.currentIndex,
                    isLoop: false,
                    allowedSwipeDirection: const AllowedSwipeDirection.only(
                      left: true,
                      right: true,
                      up: true,
                    ),
                    onSwipe: _onSwipe,
                    onSwipeDirectionChange: _onSwipeDirectionChange,
                    cardBuilder: (ctx, index, percentX, percentY) {
                      if (index >= session.students.length) {
                        return const SizedBox.shrink();
                      }
                      return StudentSwipeCard(
                        student: session.students[index],
                        swipeDirection: index == session.currentIndex
                            ? _currentDirection
                            : null,
                      );
                    },
                  ),
                ),
              ),
              // Action buttons — wired in plan 06-02
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
