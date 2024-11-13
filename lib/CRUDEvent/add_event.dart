import 'package:flutter/material.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({
    super.key,
    required this.addOrEditEvent,
    this.selectedDate,
    this.initialEvent,
  });

  final Function(DateTime, Event) addOrEditEvent;
  final DateTime? selectedDate;
  final Event? initialEvent;

  @override
  _AddEventScreenState createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startDate;
  TimeOfDay? _startTime;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategory;
  final List<String> _categories = ['Personal', 'Work', 'Social', 'Others'];

  @override
  void initState() {
    super.initState();
    if (widget.initialEvent != null) {
      final event = widget.initialEvent!;
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _startDate = event.startDate;
      _startTime = event.startTime;
      _selectedCategory = event.category;
    } else {
      _startDate = widget.selectedDate ?? DateTime.now();
      _startTime = TimeOfDay.now();
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = _startDate ?? DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _startTime!,
    );
    if (pickedTime != null) {
      setState(() {
        _startTime = pickedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEvent != null;
    final theme = Theme.of(context); // Access current theme
    final appBarColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : theme.colorScheme
        .primary; // Dark mode: lighter AppBar, Light mode: primary color
    final titleColor = theme.colorScheme.onSurface; // Title color for contrast

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isEditing ? "Edit Event" : "Create New Event",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: titleColor, // Dynamic text color for AppBar title
          ),
        ),
        backgroundColor: appBarColor, // Dynamic AppBar color
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(26, 13, 26, 0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(
                          0.7)), // Dynamic label color
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                // Dynamic text color
                validator: (value) =>
                value == null || value.isEmpty
                    ? 'Please enter the event title'
                    : null,
              ),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Date',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(color: theme.colorScheme
                              .onSurface.withOpacity(0.7)),
                        ),
                        child: Text(
                          style: TextStyle(color: theme.colorScheme
                              .onSurface),
                          _startDate == null ? 'Select Date' : '${_startDate!
                              .toLocal()}'.split(' ')[0],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Time',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(color: theme.colorScheme
                              .onSurface.withOpacity(0.7)),
                        ),
                        child: Text(
                          _startTime == null ? 'Select Time' : _startTime!
                              .format(context),
                          style: TextStyle(color: theme.colorScheme
                              .onSurface),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Event Description',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 20.0),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
                value: _selectedCategory,
                items: _categories
                    .map((category) =>
                    DropdownMenuItem(
                      value: category,
                      child: Text(category, style: TextStyle(color: theme
                          .colorScheme.onSurface)),
                    ))
                    .toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                },
                validator: (value) =>
                value == null
                    ? 'Please select a category'
                    : null,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (_startDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Please select a start date"),
                          backgroundColor: theme.colorScheme
                              .error, // Dynamic error color
                        ),
                      );
                      return;
                    }

                    final newEvent = Event(
                      title: _titleController.text,
                      description: _descriptionController.text,
                      startDate: _normalizeDate(_startDate!),
                      startTime: _startTime,
                      category: _selectedCategory!,
                    );

                    widget.addOrEditEvent(
                        _normalizeDate(_startDate!), newEvent);
                    Navigator.pop(context);
                  }
                },
                style: ButtonStyle(
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  foregroundColor: WidgetStateProperty.all(
                      theme.colorScheme.onPrimary), // Dynamic button text color
                  backgroundColor: WidgetStateProperty.all(theme.colorScheme
                      .primary), // Dynamic button background color
                ),
                child: Text(isEditing ? "Save Changes" : "Add Event"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class Event {
  final String title;
  final String description;
  final DateTime startDate;
  final TimeOfDay? startTime;
  final String category;
  bool isNotificationOn; // The isNotificationOn field is mutable and can be updated.


  Event({
    required this.title,
    required this.description,
    required this.startDate,
    // this.endDate,
    this.startTime,
    // this.endTime,
    required this.category,
    this.isNotificationOn = false, // Default to off

  });
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'startDate': startDate.toIso8601String(),
    // 'endDate': endDate?.toIso8601String(),
    'startTime': startTime != null
        ? '${startTime!.hour}:${startTime!.minute}'
        : null,
    // 'endTime': endTime != null
    //     ? '${endTime!.hour}:${endTime!.minute}'
    //     : null,
    'category': category,
    'isNotificationOn': isNotificationOn, // Boolean value
  };

  factory Event.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? time) {
      if (time == null) return null;
      final parts = time.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return Event(
      title: json['title'],
      description: json['description'],
      startDate: DateTime.parse(json['startDate']),
      // endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      startTime: parseTime(json['startTime']),
      // endTime: parseTime(json['endTime']),
      category: json['category'],
      isNotificationOn: json['isNotificationOn'] == null
          ? false // Default to false if the value is null
          : json['isNotificationOn'] as bool, // Cast the value to bool
    );
  }
}