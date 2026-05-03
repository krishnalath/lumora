import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'add_task_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  late DateTime _today;
  late DateTime _selectedDate;
  late DateTime _queryDate;
  Timer? _debounce;
  Timer? _minuteTimer;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _selectedDate = DateTime(_today.year, _today.month, _today.day);
    _queryDate = _selectedDate;
    // Start page controller at a large number so we can scroll infinitely in both directions
    _pageController = PageController(initialPage: 5000, viewportFraction: 0.18);

    // Realtime checker for auto-shifting tasks
    _minuteTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _minuteTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Generate dates based on selected page relative to today
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Tasks',
          style: GoogleFonts.dmSans(
            color: AppTheme.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E5FF),
        child: const Icon(Icons.add, color: Colors.black),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTaskScreen(initialDate: _selectedDate),
            ),
          );
        },
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Month/Year Selector
          GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppTheme.primary,
                        onPrimary: Colors.black,
                        surface: Colors.white,
                        onSurface: AppTheme.textDark,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _queryDate = picked;
                  final diff = picked.difference(DateTime(_today.year, _today.month, _today.day)).inDays;
                  _pageController.jumpToPage(5000 + diff);
                });
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down, color: AppTheme.textMedium),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Horizontal Date Selector
          SizedBox(
            height: 100,
            child: PageView.builder(
              controller: _pageController,
              pageSnapping: false,
              onPageChanged: (index) {
                final date = DateTime(_today.year, _today.month, _today.day + (index - 5000));
                setState(() {
                  _selectedDate = date;
                });
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() {
                    _queryDate = date;
                  });
                });
              },
              itemBuilder: (context, index) {
                final date = DateTime(_today.year, _today.month, _today.day + (index - 5000));
                final isSelected = _isSameDay(date, _selectedDate);

                return GestureDetector(
                  onTap: () {
                    // Animate to center this item
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE2F0CB) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: isSelected ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          style: GoogleFonts.dmSans(
                            color: isSelected ? const Color(0xFF1E212B) : AppTheme.textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('E').format(date),
                          style: GoogleFonts.dmSans(
                            color: isSelected ? const Color(0xFF1E212B).withOpacity(0.7) : AppTheme.textMedium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Background curve effect
          Expanded(
            child: Stack(
              children: [
                // Curved background top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 25),
                  color: Colors.white,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService().getTasksForDate(_queryDate),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const SizedBox(); // Smooth buffer
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt, size: 64, color: AppTheme.textLight.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                'No tasks for this day.',
                                style: GoogleFonts.dmSans(color: AppTheme.textMedium, fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      final tasks = snapshot.data!.docs.map((doc) {
                        final task = TaskModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                        
                        // Auto-shift 'Upcoming' to 'Running' if start time has passed
                        if (task.status.toLowerCase() == 'upcoming') {
                          final now = DateTime.now();
                          final start = DateTime(task.date.year, task.date.month, task.date.day, task.startTime.hour, task.startTime.minute);
                          if (now.isAfter(start) || now.isAtSameMomentAs(start)) {
                            // Fire and forget Firestore update
                            FirestoreService().updateTask(task.id, {'status': 'Running'});
                            
                            // Return an updated local copy for immediate display
                            return TaskModel(
                              id: task.id,
                              uid: task.uid,
                              title: task.title,
                              category: task.category,
                              status: 'Running',
                              date: task.date,
                              startTime: task.startTime,
                              endTime: task.endTime,
                              progress: task.progress,
                              isPinned: task.isPinned,
                              pinnedAt: task.pinnedAt,
                              createdAt: task.createdAt,
                            );
                          }
                        }
                        
                        return task;
                      }).toList();

                      // Sort: Pinned first (by pinnedAt order), then by status (completed last), then by start time
                      tasks.sort((a, b) {
                        // Priority 1: Pin status
                        if (a.isPinned != b.isPinned) {
                          return a.isPinned ? -1 : 1;
                        }
                        
                        // Priority 2: Pinning order (if both pinned)
                        if (a.isPinned && b.isPinned) {
                          final aTime = a.pinnedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
                          final bTime = b.pinnedAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
                          if (aTime != bTime) {
                            return aTime.compareTo(bTime);
                          }
                        }

                        // Priority 3: Completion status
                        final aIsCompleted = a.status.toLowerCase() == 'completed' ? 1 : 0;
                        final bIsCompleted = b.status.toLowerCase() == 'completed' ? 1 : 0;
                        if (aIsCompleted != bIsCompleted) {
                          return aIsCompleted.compareTo(bIsCompleted);
                        }

                        // Priority 4: Start time
                        final aMin = a.startTime.hour * 60 + a.startTime.minute;
                        final bMin = b.startTime.hour * 60 + b.startTime.minute;
                        return aMin.compareTo(bMin);
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          return _buildTaskTimelineItem(tasks[index], index == tasks.length - 1);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildTaskTimelineItem(TaskModel task, bool isLast) {
    // Determine color based on status
    Color cardColor;
    switch (task.status.toLowerCase()) {
      case 'completed':
        cardColor = const Color(0xFFD4E7C5); // Light green
        break;
      case 'running':
        cardColor = const Color(0xFFE2D4E1); // Light Purple/Pink
        break;
      case 'upcoming':
      default:
        cardColor = const Color(0xFF4EE2F2); // Cyan/Light Blue
        break;
    }

    final formatTime = (TimeOfDay t) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      return DateFormat('hh a').format(dt).toLowerCase();
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column
          SizedBox(
            width: 60,
            child: task.status.toLowerCase() == 'completed'
              ? const SizedBox()
              : Column(
                  children: [
                Text(
                  formatTime(task.startTime),
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textMedium,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                    ),
                    // Dash effect could be achieved with a custom painter or dashed line package
                  ),
                ),
                Text(
                  formatTime(task.endTime),
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textMedium,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (!isLast) const SizedBox(height: 32),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Task Card
          Expanded(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.status,
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFF1E212B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (task.isPinned)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: Icon(Icons.push_pin, size: 16, color: Color(0xFF1E212B)),
                                      ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddTaskScreen(
                                              initialDate: _selectedDate,
                                              taskToEdit: task,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Icon(Icons.chevron_right, size: 24, color: Color(0xFF1E212B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Title & Category & Options
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: GoogleFonts.dmSans(
                                          color: const Color(0xFF1E212B),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        task.category,
                                        style: GoogleFonts.dmSans(
                                          color: const Color(0xFF1E212B).withOpacity(0.6),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Quick Actions
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        task.status.toLowerCase() == 'completed' ? Icons.check_circle : Icons.check_circle_outline,
                                        color: const Color(0xFF1E212B),
                                      ),
                                      onPressed: () {
                                        final newStatus = task.status.toLowerCase() == 'completed' ? 'Upcoming' : 'Completed';
                                        FirestoreService().updateTask(task.id, {'status': newStatus});
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        task.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                        color: const Color(0xFF1E212B),
                                      ),
                                      onPressed: () {
                                        FirestoreService().updateTask(task.id, {
                                          'isPinned': !task.isPinned,
                                          'pinnedAt': !task.isPinned ? FieldValue.serverTimestamp() : null,
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(
                    color: Color(0xFFE2E8F0),
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
