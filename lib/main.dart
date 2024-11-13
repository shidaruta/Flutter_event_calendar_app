import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:eventcalendarapp/Events/events.dart';
import 'package:eventcalendarapp/CRUDEvent/add_event.dart';

import 'theme_provider.dart'; // Import the ThemeProvider
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  // Initialize timezone data
  tz.initializeTimeZones();
  WidgetsFlutterBinding.ensureInitialized();
  // Run the app
  runApp(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}
Future<void> requestNotiPermission() async {
  final status = await Permission.notification.request();

  if (status.isGranted) {
    showSnackBar('Notification permission granted.');
  } else {
    showSnackBar('Notification permission not granted. Please enable it in settings.');
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showSnackBar(String message) {
  // Find the current context to show SnackBar
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {  // Provide the navigatorKey to access the context
    requestNotiPermission();

    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeProvider.themeData,
        home: const Events(
          selectedEvents: {},
        ),
      );
    });
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DateTime _focusedDay = DateTime.now(); // Initial focus on the current day
  Map<DateTime, List<Event>> selectedEvents = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final storedEvents = prefs.getString('events') ?? '{}';
    final Map<String, dynamic> jsonMap = json.decode(storedEvents);

    // Parse JSON and normalize dates
    final loadedEvents = jsonMap.map((key, value) {
      final date = DateTime.parse(key);
      final eventsList = (value as List)
          .map((eventData) => Event.fromJson(eventData))
          .toList();
      return MapEntry(date, eventsList);
    });

    setState(() {
      selectedEvents = loadedEvents
          .map((date, events) => MapEntry(_normalizeDate(date), events));
    });
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonMap = selectedEvents.map((key, value) => MapEntry(
        key.toIso8601String(), value.map((event) => event.toJson()).toList()));

    await prefs.setString('events', json.encode(jsonMap));
  }

  List<Event> _getEventsForDay(DateTime day) {
    DateTime normalizedDay = _normalizeDate(day);
    return selectedEvents[normalizedDay] ?? [];
  }

  void _addEvent(DateTime day, Event event) {
    final normalizedDay = _normalizeDate(day);

    if (selectedEvents[normalizedDay] != null) {
      selectedEvents[normalizedDay]!.add(event);
    } else {
      selectedEvents[normalizedDay] = [event];
    }
    _saveEvents();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Trigger the search functionality
              showSearch(
                context: context,
                delegate: EventSearchDelegate(selectedEvents),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(
              height: 60.0,
            ),
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
                      builder: (context) => Events(
                        selectedEvents: selectedEvents,
                      )),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: TableCalendar(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                eventLoader: _getEventsForDay,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _focusedDay = _normalizeDate(focusedDay);
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Events(
                        selectedEvents: {
                          selectedDay: _getEventsForDay(selectedDay)
                        },
                        selectedDate:
                        selectedDay, // Pass the selected date here
                      ),
                    ),
                  );
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isNotEmpty) {
                      return ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.lightBlueAccent,
                            ),
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.blue),
                  rightChevronIcon:
                  Icon(Icons.chevron_right, color: Colors.blue),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.black87),
                  weekendStyle: TextStyle(color: Colors.redAccent),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  outsideDecoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEventScreen(
                addOrEditEvent: _addEvent,
                selectedDate: _focusedDay,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Custom Search Delegate for searching events
class EventSearchDelegate extends SearchDelegate {
  final Map<DateTime, List<Event>> selectedEvents;

  EventSearchDelegate(this.selectedEvents);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _searchEvents(query);

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final event = results[index];
        return ListTile(
          title: Text(event.title),
          subtitle: Text('${event.description}\nCategory: ${event.category}'),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Search for events',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
      );
    }

    final suggestions = _searchEvents(query);

    if (suggestions.isEmpty) {
      return const Center(
        child: Text(
          'No events found',
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final event = suggestions[index];
        return ListTile(
          title: Text(event.title),
          subtitle: Text('${event.description}\nCategory: ${event.category}'),
        );
      },
    );
  }

  List<Event> _searchEvents(String query) {
    List<Event> events = [];

    // Search through all events
    selectedEvents.forEach((date, eventList) {
      for (var event in eventList) {
        if (event.title.toLowerCase().contains(query.toLowerCase()) ||
            event.description.toLowerCase().contains(query.toLowerCase())) {
          events.add(event);
        }
      }
    });

    return events;
  }
}
