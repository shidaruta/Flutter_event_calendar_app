import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../CRUDEvent/add_event.dart';
import '../main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../theme_provider.dart';

class Events extends StatefulWidget {
  final Map<DateTime, List<Event>> selectedEvents;

  final DateTime? selectedDate; // Add this field for the clicked date

  const Events({super.key, required this.selectedEvents, this.selectedDate});

  @override
  _EventsState createState() => _EventsState();
}

class _EventsState extends State<Events> with SingleTickerProviderStateMixin {
  bool isSearching = false;
  DateTime? _selectedDate;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  TextEditingController searchController = TextEditingController();

  List<Event> filteredEvents = [];
  Map<DateTime, List<Event>> allEvents = {};

  String selectedFilter = "Today"; // Default selected value
  String selectedCategory = "All"; // Default category filter
  int selectedIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    initializeNotifications();

    _selectedDate = widget.selectedDate; // Initialize selectedDate
    allEvents = widget.selectedEvents;
    _resetFilteredEvents();

    _tabController = TabController(length: categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        // Ensure tab has fully changed
        setState(() {
          selectedCategory = categories[_tabController.index];
          selectedIndex = _tabController.index;
          _resetFilteredEvents();
        });
      }
    });
  }

  void initializeNotifications() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
        'app_icon'); // Provide an icon for Android
    var initializationSettingsIOS = const DarwinInitializationSettings();

    final initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void scheduleNotification(Event event) async {
    // Check for notification permission (not exact alarm permission)
    final status = await Permission.notification.request();

    if (!status.isGranted) {
      showSnackBar("Notification permission not granted.");
      return;
    }

    try {
      final DateTime notificationTime = DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
        event.startTime?.hour ?? 0,
        event.startTime?.minute ?? 0,
      );
      var bhutan = tz.getLocation('Asia/Thimphu');
      final tz.TZDateTime scheduledTime =
          tz.TZDateTime.from(notificationTime, bhutan);

      if (scheduledTime.isBefore(tz.TZDateTime.now(bhutan))) {
        showSnackBar(
            "Scheduled time is in the past. Cannot schedule notification.");
        return;
      }

      // Define Android notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'event_channel_id',
        'Event Notifications',
        channelDescription: 'Notifications for event start times',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      // Define iOS notification details
      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true, // Show an alert
        presentBadge: true, // Update the badge count
        presentSound: true, // Play a sound
      );

      // Combine platform-specific details
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      // Schedule notification for both Android and iOS
      await flutterLocalNotificationsPlugin.zonedSchedule(
        event.hashCode,
        'Event Reminder',
        event.title,
        scheduledTime,
        platformDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      showSnackBar(
          "Notification scheduled for event: ${event.title} at $scheduledTime");
    } catch (e) {
      showSnackBar("Failed to schedule notification: ${e.toString()}");
    }
  }

  void cancelNotification(Event event) async {
    await flutterLocalNotificationsPlugin.cancel(event.hashCode);
    showSnackBar("Notification cancelled for event: ${event.title}");
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void toggleNotification(Event event) async {
    final DateTime notificationTime = DateTime(
      event.startDate.year,
      event.startDate.month,
      event.startDate.day,
      event.startTime?.hour ?? 0,
      event.startTime?.minute ?? 0,
    );
    // Update the notification state
    var bhutan = tz.getLocation('Asia/Thimphu');
    final tz.TZDateTime scheduledTime =
        tz.TZDateTime.from(notificationTime, bhutan);

    if (scheduledTime.isBefore(tz.TZDateTime.now(bhutan))) {
      showSnackBar("Cannot toggle notification for past events.");
      return;
    }
    setState(() {
      event.isNotificationOn = !event.isNotificationOn;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNotificationOn_${event.hashCode}',
        event.isNotificationOn); // Unique key

    // Schedule or cancel the notification based on the updated state
    if (event.isNotificationOn) {
      scheduleNotification(event);
    } else {
      cancelNotification(event);
    }
  }

  final List<String> categories = [
    'All',
    'Work',
    'Personal',
    'Social',
    'Others'
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadEventsFromPreferences(); // Load events each time the screen is displayed
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEventsFromPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? eventsJson = prefs.getString('events');
    if (eventsJson != null) {
      Map<String, dynamic> decodedJson = jsonDecode(eventsJson);
      setState(() {
        allEvents = decodedJson.map((key, value) {
          DateTime date = DateTime.parse(key);
          List<Event> events =
              (value as List).map((e) => Event.fromJson(e)).toList();
          return MapEntry(date, events);
        });
        _resetFilteredEvents();
      });
    }
  }

  Future<void> _saveEventsToPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> jsonEvents = allEvents.map((key, value) =>
        MapEntry(key.toIso8601String(), value.map((e) => e.toJson()).toList()));

    await prefs.setString('events', jsonEncode(jsonEvents)).then((_) {
      setState(() {});
    });
  }

  void _resetFilteredEvents() {
    DateTime today = DateTime.now();
    DateTime upcomingEndDate = today.add(const Duration(days: 7));

    setState(() {
      filteredEvents = allEvents.entries
          .where((entry) {
            bool dateMatches;

            if (_selectedDate != null) {
              // Only show events for the selected date
              dateMatches = entry.key.isAtSameMomentAs(
                DateTime(_selectedDate!.year, _selectedDate!.month,
                    _selectedDate!.day),
              );
            } else if (selectedFilter == "Today") {
              dateMatches = entry.key.isAtSameMomentAs(
                  DateTime(today.year, today.month, today.day));
            } else if (selectedFilter == "Upcoming") {
              dateMatches = entry.key.isAfter(today) &&
                  entry.key.isBefore(upcomingEndDate);
            } else {
              dateMatches = true;
            }

            // Ensure category filter works correctly
            bool categoryMatches = selectedCategory == "All" ||
                entry.value.any((event) => event.category == selectedCategory);

            return dateMatches && categoryMatches;
          })
          .expand((entry) => entry.value)
          .toList();
    });
  }

  void onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      selectedFilter = ""; // Clear any other filter when a date is chosen
    });
    _resetFilteredEvents();
  }

  void _filterEvents(String query) {
    if (query.isEmpty) {
      // Reset to filtered events without search query
      _resetFilteredEvents();
    } else {
      setState(() {
        // Filter from currently set filteredEvents with the search query
        filteredEvents = filteredEvents
            .where((event) =>
                event.title.toLowerCase().contains(query.toLowerCase()) ||
                event.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  void _addOrEditEvent(DateTime newDate, Event newEvent) {
    setState(() {
      // Create a mutable copy of the allEvents map
      var mutableEvents = Map<DateTime, List<Event>>.from(allEvents);

      // Remove event from the old date entry if it exists
      final originalDate = mutableEvents.keys.firstWhere(
        (date) => mutableEvents[date]?.contains(newEvent) ?? false,
        orElse: () => newDate,
      );

      if (mutableEvents[originalDate] != null) {
        // Make sure the list is mutable before modifying it
        mutableEvents[originalDate] = List.from(
            mutableEvents[originalDate]!); // Create a mutable copy of the list
        mutableEvents[originalDate]?.remove(newEvent);
        if (mutableEvents[originalDate]!.isEmpty) {
          mutableEvents
              .remove(originalDate); // Remove the date key if no events left
        }
      }

      // Add event to the new date entry
      if (mutableEvents.containsKey(newDate)) {
        mutableEvents[newDate]!.add(newEvent);
      } else {
        mutableEvents[newDate] = [newEvent];
      }

      // Update the original allEvents map with the mutable copy
      allEvents = mutableEvents;

      // Save updated events and refresh filtered events after adding
      _saveEventsToPreferences();
      _resetFilteredEvents();
    });
  }

  String getImageForCategory(String category) {
    switch (category) {
      case 'Work':
        return 'assets/Work.png';
      case 'Personal':
        return 'assets/personal.png';
      case 'Social':
        return 'assets/social.png';
      case 'Others':
        return 'assets/others.png';
      default:
        return 'assets/others.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: isSearching
            ? TextField(
                controller: searchController,
                autofocus: true,
                onChanged: _filterEvents,
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onPrimary.withOpacity(0.7),
                  ),
                ),
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 18.0,
                ),
              )
            : (_selectedDate != null)
                ? Text(
                    DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 18.0,
                    ),
                  )
                : DropdownButton<String>(
                    value: selectedFilter,
                    underline: Container(),
                    dropdownColor: theme.colorScheme.primary,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                    ),
                    items: <String>['Today', 'Upcoming'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedFilter = newValue!;
                        _selectedDate = null;
                        _resetFilteredEvents();
                      });
                    },
                  ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.colorScheme.onPrimary, // Selected tab text color
          unselectedLabelColor: theme.colorScheme.onPrimary
              .withOpacity(0.7), // Unselected tab text color
          indicatorColor: theme.colorScheme.onPrimary, // Indicator color
          tabs: categories.map((category) => Tab(text: category)).toList(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSearching ? Icons.close : Icons.search,
            ),
            onPressed: () {
              setState(() {
                if (isSearching) {
                  searchController.clear();
                  _resetFilteredEvents();
                }
                isSearching = !isSearching;
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 60.0),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text("Calendar"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const MyHomePage(title: "Calendar App"),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text("Events"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Events(selectedEvents: allEvents),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text("Theme"),
              trailing: Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return Switch(
                    value: themeProvider.isDarkTheme,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: categories.map((category) {
          var categoryFilteredEvents = filteredEvents
              .where((event) => event.category == category || category == "All")
              .toList();

          return categoryFilteredEvents.isEmpty
              ? Center(
                  child: Text(
                    "No events found",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18.0,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 90.0),
                  itemCount: categoryFilteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = categoryFilteredEvents[index];
                    final date = allEvents.keys.firstWhere(
                      (date) => allEvents[date]!.contains(event),
                      orElse: () => DateTime.now(),
                    );

                    final timeString = event.startTime != null
                        ? "${event.startTime!.hourOfPeriod}:${event.startTime!.minute.toString().padLeft(2, '0')} ${event.startTime!.period == DayPeriod.am ? 'AM' : 'PM'}"
                        : '';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddEventScreen(
                              selectedDate: date,
                              addOrEditEvent:
                                  (DateTime newDate, Event updatedEvent) {
                                setState(() {
                                  if (allEvents[date] != null) {
                                    allEvents[date]!.remove(event);
                                    if (allEvents[date]!.isEmpty) {
                                      allEvents.remove(date);
                                    }
                                  }
                                  if (allEvents.containsKey(newDate)) {
                                    allEvents[newDate]!.add(updatedEvent);
                                  } else {
                                    allEvents[newDate] = [updatedEvent];
                                  }
                                  _saveEventsToPreferences();
                                  _resetFilteredEvents();
                                });
                              },
                              initialEvent: event,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10.0),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.1),
                              blurRadius: 6.0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Image.asset(
                                      getImageForCategory(event.category),
                                      width: 40,
                                      height: 40,
                                    ),
                                    const SizedBox(width: 20),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16.0,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        timeString.isNotEmpty
                                            ? Row(
                                                children: [
                                                  Text(
                                                    DateFormat(
                                                            'EEEE, dd MMMM yyyy')
                                                        .format(
                                                            event.startDate),
                                                    style: TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      fontSize: 12,
                                                      color: theme
                                                          .colorScheme.onSurface
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    timeString,
                                                    style: TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      fontSize: 12,
                                                      color: theme
                                                          .colorScheme.onSurface
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Container(),
                                      ],
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(
                                    event.isNotificationOn
                                        ? Icons.notifications
                                        : Icons.notifications_none,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  onPressed: () {
                                    toggleNotification(
                                        event); // Call the toggle function to switch notification state
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    event.description,
                                    softWrap: true,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text('Confirm Deletion'),
                                          content: const Text(
                                              'Are you sure you want to delete this event?'),
                                          actions: <Widget>[
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  allEvents[date]
                                                      ?.remove(event);
                                                  if (allEvents[date]
                                                          ?.isEmpty ??
                                                      false) {
                                                    allEvents.remove(date);
                                                  }
                                                  _saveEventsToPreferences();
                                                  _resetFilteredEvents();
                                                });
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEventScreen(
                addOrEditEvent: _addOrEditEvent,
                selectedDate: DateTime.now(),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
