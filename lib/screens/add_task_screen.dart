import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AddTaskScreen extends StatefulWidget {
  final DateTime initialDate;
  final TaskModel? taskToEdit;

  const AddTaskScreen({super.key, required this.initialDate, this.taskToEdit});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  
  String _selectedCategory = 'Self growth';
  final List<String> _categories = ['Self growth', 'Family task', 'College', 'Home', 'Work'];

  String _selectedStatus = 'Upcoming';
  final List<String> _statuses = ['Running', 'Upcoming'];

  int _progress = 0;
  bool _isPinned = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _selectedDate = t.date;
      _startTime = t.startTime;
      _endTime = t.endTime;
      _selectedCategory = _categories.contains(t.category) ? t.category : 'Self growth';
      _selectedStatus = _statuses.contains(t.status) ? t.status : 'Upcoming';
      _progress = t.progress;
      _isPinned = t.isPinned;
    } else {
      _selectedDate = widget.initialDate;
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay(hour: _startTime.hour + 1, minute: _startTime.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      AppTheme.showCustomSnackBar(context, 'Please enter a task title', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.taskToEdit == null) {
        await FirestoreService().createTask(
          title: _titleController.text.trim(),
          category: _selectedCategory,
          status: _selectedStatus,
          date: _selectedDate,
          startTime: _startTime,
          endTime: _endTime,
          progress: _progress,
          isPinned: _isPinned,
        );
      } else {
        await FirestoreService().updateTask(widget.taskToEdit!.id, {
          'title': _titleController.text.trim(),
          'category': _selectedCategory,
          'status': _selectedStatus,
          'date': Timestamp.fromDate(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)),
          'startTime': '${_startTime.hour}:${_startTime.minute}',
          'endTime': '${_endTime.hour}:${_endTime.minute}',
          'progress': _progress,
          'isPinned': _isPinned,
        });
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showCustomSnackBar(context, e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
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
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.taskToEdit == null ? 'New Task' : 'Edit Task',
          style: GoogleFonts.dmSans(color: AppTheme.textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Title'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: GoogleFonts.dmSans(color: AppTheme.textDark),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'e.g. Web Design',
                hintStyle: GoogleFonts.dmSans(color: AppTheme.textMedium.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildLabel('Category'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  style: GoogleFonts.dmSans(color: AppTheme.textDark),
                  items: _categories.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildLabel('Status'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  style: GoogleFonts.dmSans(color: AppTheme.textDark),
                  items: _statuses.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Date'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppTheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_selectedDate),
                                style: GoogleFonts.dmSans(color: AppTheme.textDark),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Start Time'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _selectTime(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: AppTheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _startTime.format(context),
                                style: GoogleFonts.dmSans(color: AppTheme.textDark),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('End Time'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _selectTime(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, color: AppTheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _endTime.format(context),
                                style: GoogleFonts.dmSans(color: AppTheme.textDark),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),


            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text(
                        widget.taskToEdit == null ? 'Create Task' : 'Save Changes',
                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            if (widget.taskToEdit != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          try {
                            await FirestoreService().deleteTask(widget.taskToEdit!.id);
                            if (mounted) Navigator.pop(context);
                          } catch (e) {
                            if (mounted) AppTheme.showCustomSnackBar(context, e.toString(), isError: true);
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Delete Task',
                    style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        color: AppTheme.textMedium,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}
