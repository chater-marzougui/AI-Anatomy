import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;

// Add this new model class to store medication information
class MedicationReminder {
  final String medicineName;
  final String description;
  final List<String> times;
  final int id;

  MedicationReminder({
    required this.medicineName,
    required this.description,
    required this.times,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
    'medicineName': medicineName,
    'description': description,
    'times': times,
    'id': id,
  };

  factory MedicationReminder.fromJson(Map<String, dynamic> json) {
    return MedicationReminder(
      medicineName: json['medicineName'],
      description: json['description'],
      times: List<String>.from(json['times']),
      id: json['id'],
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone
  tz_init.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Tunis')); // Set to Tunisia's timezone
  runApp(MentalHealthChatbotApp());
}

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });
}

class MentalHealthChatbotApp extends StatelessWidget {
  final ThemeProvider themeProvider = ThemeProvider();

  MentalHealthChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: themeProvider,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'The Flying Dutchman',
            theme: ThemeData(
              primaryColor: Color(0xFF2A93D5),
              scaffoldBackgroundColor: themeProvider.isDarkMode ? Color(0xFF121212) : Colors.white,
              colorScheme: ColorScheme.fromSwatch().copyWith(
                primary: Color(0xFF2A93D5),
                secondary: Color(0xFF37CAEC),
                surface: themeProvider.isDarkMode ? Color(0xFF121212) : Colors.white,
              ),
              textTheme: Theme.of(context).textTheme.apply(
                bodyColor: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                displayColor: themeProvider.isDarkMode ? Colors.white : Colors.black87,
              ),
              appBarTheme: AppBarTheme(
                elevation: 0,
                color: themeProvider.isDarkMode ? Color(0xFF1E1E1E) : Color(0xFF2A93D5),
              ),
            ),
            home: MentalHealthChatScreen(themeProvider: themeProvider),
          );
        }
    );
  }
}

class MentalHealthChatScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  const MentalHealthChatScreen({super.key, required this.themeProvider});

  @override
  State<MentalHealthChatScreen> createState() => _MentalHealthChatScreenState();
}

class _MentalHealthChatScreenState extends State<MentalHealthChatScreen> with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: 'AIzaSyD7Ub-fmdXtKoLH6rFBThNDKEA3NKiMAbA');
  late AnimationController _animationController;
  String _currentLang = "english";

  // Notification related variables
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  List<MedicationReminder> _medicationReminders = [];
  int _notificationIdCounter = 0;

  // Speech to text instance
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  // Text to speech instance
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = true;

  // User avatar SVG string
  final String userAvatarSvg = '''
  <svg width="40" height="40" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="24" height="24" rx="12" fill="#37CAEC"/>
    <circle cx="12" cy="8" r="3.5" stroke="white" stroke-width="1.5"/>
    <path d="M5.5 19C5.5 15.5 8 13 12 13C16 13 18.5 15.5 18.5 19" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
  </svg>
  ''';


  // Project information to be shared when asked
  final Map<String, String> projectInfo = {
    "name": "AI Anatomy",
    "creators": "Chater Marzougui", // Add team members here
    "school": "Sup'Com",
    "contact": "Chater Marzougui: 55 123 456",
    "class": "AI Anatomy Project",
    "professor": "None", // Professor name
    "created_date": "20 april 2025", // When you created it
    "purpose": "Assistance in identifying how to use medics and reminding the users"
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _initPermissions();

    // Initialize notifications
    _initNotifications();

    // Load saved medication reminders
    _loadSavedReminders();

    // Initialize speech recognition
    _initSpeech();

    // Initialize text to speech
    _initTts();

    // Add a welcome message when the app starts
    _addMessage("Hi there! I'm ${projectInfo['name']}, your assistant. How are you feeling today?", false);

    _testImmediateNotification();
  }

  void _testImmediateNotification() async {
    final now = DateTime.now();
    final scheduledTime = now.add(Duration(seconds: 10));

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      999, // Unique test ID
      'Test Notification',
      'This is scheduled to appear in 1 minute',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Channel for testing notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    print('Test notification scheduled for: $scheduledTime');
  }



  void _initPermissions() async {
    // Request notification permission
    if (await Permission.notification.isPermanentlyDenied) {
      openAppSettings();
    } else if (await Permission.notification.isRestricted) {
      openAppSettings();
    } else if (await Permission.notification.isLimited) {
      openAppSettings();
    } else if (await Permission.notification.isGranted) {
      // Permission already granted
    } else if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  // Initialize notifications
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tapped logic here
      },
    );

    final androidPlugin = _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'test_channel', // Same as your zonedSchedule channel ID
      'Test Notifications',
      description: 'Channel for testing notifications',
      importance: Importance.max,
    ));
  }

  // Load saved medication reminders from SharedPreferences
  Future<void> _loadSavedReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final savedReminders = prefs.getStringList('medicationReminders') ?? [];

    setState(() {
      _medicationReminders = savedReminders
          .map((reminder) => MedicationReminder.fromJson(json.decode(reminder)))
          .toList();

      // Get the highest notification ID to continue from there
      if (_medicationReminders.isNotEmpty) {
        _notificationIdCounter = _medicationReminders
            .map((reminder) => reminder.id)
            .reduce((value, element) => value > element ? value : element) + 1;
      }
    });

    // Re-schedule all existing reminders when app starts
    for (final reminder in _medicationReminders) {
      _scheduleNotificationsForReminder(reminder);
    }

    await _flutterLocalNotificationsPlugin.show(
      1000,
      'Immediate Notification',
      'This should appear instantly',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Channel for testing notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

  }

  // Save medication reminders to SharedPreferences
  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = _medicationReminders
        .map((reminder) => json.encode(reminder.toJson()))
        .toList();
    await prefs.setStringList('medicationReminders', remindersJson);
  }

  // Extract medication info from AI response
  void _processMedicationInfo(Map<String, dynamic> jsonResponse) {
    final responseText = jsonResponse['response'] as String;

    // Check if response contains medication timing information
    final hasTimingInfo = RegExp(r'\d{1,2}:\d{2}\s*(AM|PM)', caseSensitive: false).hasMatch(responseText);

    if (hasTimingInfo) {
      // Extract medicine name (this is a simple heuristic - improve based on your model's output format)
      String medicineName = "Medication";
      final medicineNameMatch = RegExp(r'for\s+([A-Za-z\s]+)', caseSensitive: false).firstMatch(responseText);
      if (medicineNameMatch != null) {
        medicineName = medicineNameMatch.group(1)?.trim() ?? "Medication";
      }

      // Extract all times in the format HH:MM AM/PM
      final timeRegex = RegExp(r'(\d{1,2}:\d{2}\s*(AM|PM))', caseSensitive: false);
      final matches = timeRegex.allMatches(responseText);

      if (matches.isNotEmpty) {
        final List<String> times = matches
            .map((match) => match.group(1)!)
            .toList();

        _showMedicationConfirmationDialog(medicineName, responseText, times);
      }
    }
  }

  void _showMedicationConfirmationDialog(String medicineName, String description, List<String> times) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Schedule Medication Reminder?',
          style: theme.textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Would you like to schedule reminders for:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              medicineName,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Times:', style: theme.textTheme.bodyMedium),
            ...times.map((time) => Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4.0),
              child: Text('• $time', style: theme.textTheme.bodyMedium),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: theme.textTheme.labelLarge),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createMedicationReminder(medicineName, description, times);
            },
            child: Text('Schedule', style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }

  // Create a medication reminder and schedule notifications
  void _createMedicationReminder(String medicineName, String description, List<String> times) {
    final reminder = MedicationReminder(
      medicineName: medicineName,
      description: description,
      times: times,
      id: _notificationIdCounter,
    );

    setState(() {
      _medicationReminders.add(reminder);
      _notificationIdCounter++;
    });

    // Schedule notifications for this reminder
    _scheduleNotificationsForReminder(reminder);

    // Save to persistent storage
    _saveReminders();

    // Show confirmation toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Medication reminders scheduled!'),
        backgroundColor: Color(0xFF2A93D5),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Schedule notifications for a medication reminder
  void _scheduleNotificationsForReminder(MedicationReminder reminder) {
    for (int i = 0; i < reminder.times.length; i++) {
      final time = reminder.times[i];
      _scheduleNotification(
        reminder.medicineName,
        'Time to take your ${reminder.medicineName}',
        reminder.id + i,  // Using unique IDs for each time
        _parseTimeString(time),
      );
    }
  }

  // Parse time string in format "HH:MM AM/PM" to DateTime
  DateTime _parseTimeString(String timeString) {
    // Normalize the time string format
    timeString = timeString.toUpperCase().trim();

    // Extract hours, minutes, and period
    final RegExp timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)');
    final match = timeRegex.firstMatch(timeString);

    if (match != null) {
      int hours = int.parse(match.group(1)!);
      final int minutes = int.parse(match.group(2)!);
      final String period = match.group(3)!;

      // Convert to 24-hour format
      if (period == 'PM' && hours < 12) {
        hours += 12;
      } else if (period == 'AM' && hours == 12) {
        hours = 0;
      }

      // Get current date
      final now = DateTime.now();

      // Create DateTime for today with the specified time
      DateTime scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        hours,
        minutes,
      );

      print('Now TZ: ${tz.TZDateTime.now(tz.local)}');
      print('Scheduled TZ: $scheduledTime');


      // If the time has already passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(Duration(days: 1));
      }

      return scheduledTime;
    }

    // Return default time (now + 1 minute) if parsing fails
    return DateTime.now().add(Duration(minutes: 1));
  }

  // Schedule a notification
  Future<void> _scheduleNotification(
      String title,
      String body,
      int id,
      DateTime scheduledTime,
      ) async {
    // Android-specific notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Channel for testing notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableLights: true,
      enableVibration: true,
    );

    // iOS-specific notification details
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    // General notification details
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    print("="*50);
    print(tz.local);

    // Schedule daily notification
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Makes it repeat daily
    );
  }

  // View all scheduled reminders
  void _showRemindersScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: widget.themeProvider.isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Your Medication Reminders',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.themeProvider.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: _medicationReminders.isEmpty
                    ? Center(
                  child: Text(
                    'No medication reminders yet',
                    style: TextStyle(
                      color: widget.themeProvider.isDarkMode ? Colors.white70 : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                )
                    : ListView.builder(
                  controller: controller,
                  itemCount: _medicationReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _medicationReminders[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      color: widget.themeProvider.isDarkMode ? Color(0xFF2A2A2A) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          reminder.medicineName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: widget.themeProvider.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              'Times: ${reminder.times.join(", ")}',
                              style: TextStyle(
                                color: widget.themeProvider.isDarkMode ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red[400],
                          ),
                          onPressed: () => _deleteReminder(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Delete a medication reminder
  void _deleteReminder(int index) {
    final reminder = _medicationReminders[index];

    // Cancel all notifications for this reminder
    for (int i = 0; i < reminder.times.length; i++) {
      _flutterLocalNotificationsPlugin.cancel(reminder.id + i);
    }

    setState(() {
      _medicationReminders.removeAt(index);
    });

    // Save updated reminders
    _saveReminders();

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder deleted'),
        backgroundColor: Colors.red[400],
        duration: Duration(seconds: 2),
      ),
    );

    // Close the dialog
    Navigator.pop(context);
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (errorNotification) {
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  // Initialize text to speech
  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  void _changeLanguage(String lang) async {
    String selectedLang;

    switch (lang.toLowerCase()) {
      case 'english':
        selectedLang = 'en-US';
        break;
      case 'french':
        selectedLang = 'fr-FR';
        break;
      case 'arabic':
        selectedLang = 'ar-EG';
        break;
      default:
        selectedLang = 'en-US';
    }

    await _flutterTts.setLanguage(selectedLang);
  }

  // Start listening for speech input
  void _startListening() async {
    _recognizedText = '';
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
        });
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _recognizedText = result.recognizedWords;
              _controller.text = _recognizedText;
            });
          },
          listenFor: Duration(seconds: 30),
          pauseFor: Duration(seconds: 5),
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            listenMode: stt.ListenMode.confirmation,
          ),
        );
      }
    } else {
      setState(() {
        _isListening = false;
        _speech.stop();
      });
    }
  }

  // Speak the given text
  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      setState(() {
        _isSpeaking = true;
      });
      await _flutterTts.speak(text);
    }
  }

  // Stop speaking
  Future<void> _stopSpeaking() async {
    setState(() {
      _isSpeaking = false;
    });
    await _flutterTts.stop();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _addMessage(String message, bool isUser) {
    setState(() {
      _messages.add(ChatMessage(
        content: message,
        isUser: isUser,
        timestamp: DateTime.now(),
      ));
    });
    // If it's a bot message, speak it out
    if (!isUser && !_isSpeaking) {
      _speak(message);
    }

    _scrollToBottom();
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _addMessage(message, true);
      _isLoading = true;
    });

    if (_isSpeaking) {
      await _stopSpeaking();
    }

    _scrollToBottom();
    _controller.clear();

    try {
      final conversationHistory = _messages.map((msg) =>
      '${msg.isUser ? "User" : "Assistant"}: ${msg.content}')
          .join('\n');

      // Create the prompt with system instructions and project info
      String systemPrompt = """      
        Previous Conversation:
        $conversationHistory
        
        What you need to know to know:
        You are ${projectInfo['name']}, a mental health chatbot created by ${projectInfo['creators']} at ${projectInfo['school']} for ${projectInfo['class']}. 
        You were created on ${projectInfo['created_date']} with the purpose of ${projectInfo['purpose']}.
        These are the phone numbers of professionals only if needed: ${projectInfo['contact']}
        
        When answering questions about yourself, provide some information from the given info.
        For mental health concerns:
        - Provide empathetic, supportive responses
        - Suggest healthy coping strategies
        
        Keep your responses conversational, empathetic,very short, and helpful and always respond with the same language the user used in his last message.
        
        always return a JSON object with the following keys:
        - "response": the chatbot's response as a string
        - "language": the language used in the last message, english, french or arabic
        if the user asks for timing for his medicine, provide the times he should take the medicine in in the format of "HH:MM AM/PM".
        if the user asks for a medicine, provide the name of the medicine and its description.
        if the user provides the times given by the doctor, return the times in the format of "HH:MM AM/PM".
      """;

      final content = Content.text(systemPrompt);
      final response = await model.generateContent([content]);
      final extractedJson = extractJson(response.text!);

      final jsonResponse = json.decode(extractedJson);

      setState(() {
        _isLoading = false;
      });

      if(_currentLang != jsonResponse['language']){
        _currentLang = jsonResponse['language'];
        _changeLanguage(jsonResponse['language']);
      }

      _addMessage(
        jsonResponse['response'] ?? 'I apologize, but I encountered an issue processing your request.',
        false,
      );

      // Process the response to check for medication timing info
      _processMedicationInfo(jsonResponse);

    } catch (e) {
      _addMessage("An error occurred while processing your message. Please try again.", false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    // Add a small delay to ensure the ListView has updated
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/icons/mini_logo.png',
              height: 32,
              width: 32,
            ),
            SizedBox(width: 10),
            Text(
              projectInfo['name']!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDarkMode ? Colors.white.withAlpha(200) : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          // Button to view medication reminders
          IconButton(
            icon: Icon(
              Icons.medication,
              color: isDarkMode ? Colors.white : Colors.white,
            ),
            onPressed: _showRemindersScreen,
          ),
          // Button to toggle text-to-speech
          IconButton(
            icon: Icon(
              _isSpeaking ? Icons.volume_up : Icons.volume_off,
              color: isDarkMode ? Colors.white : Colors.white,
            ),
            onPressed: () {
              if (_isSpeaking) {
                _stopSpeaking();
              } else {
                setState(() {
                  _isSpeaking = true;
                });
              }
            },
          ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: isDarkMode ? Colors.yellow : Colors.white,
            ),
            onPressed: () {
              widget.themeProvider.toggleTheme();
            },
          ),
        ],
        elevation: 0,
        backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Color(0xFF2A93D5),
      ),
      body: Container(
      decoration: BoxDecoration(
      gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDarkMode
          ? [Color(0xFF1E1E1E), Color(0xFF121212)]
          : [Color(0xFFE6F4FF), Colors.white],
    ),
    ),
    child: Column(
    children: [
    Expanded(
    child: ListView.builder(
    controller: _scrollController,
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    itemCount: _messages.length,
    itemBuilder: (context, index) {
    final message = _messages[index];
    final isUser = message.isUser;

    return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Row(
    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    if (!isUser)
    Padding(
    padding: const EdgeInsets.only(right: 8.0, top: 4.0),
    child: Image.asset(
    'assets/icons/mini_logo.png',
    height: 32,
    width: 32,
    ),
    ),
    Flexible(
    child: Container(
    constraints: BoxConstraints(
    maxWidth: MediaQuery.of(context).size.width * 0.7,
    ),
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser
            ? (isDarkMode ? Color(0xFF37CAEC).withAlpha(210) : Color(0xFF37CAEC))
            : (isDarkMode ? Color(0xFF2A2A2A) : Colors.white),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? 20 : 4),
          topRight: Radius.circular(isUser ? 4 : 20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Text(
            message.content,
            style: TextStyle(
              fontSize: 16,
              color: isUser
                  ? Colors.white
                  : (isDarkMode ? Colors.white : Colors.black87),
              height: 1.4,
            ),
          ),
          if (!isUser)
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                Icons.volume_up,
                size: 14,
                color: isDarkMode ? Colors.white30 : Colors.grey[400],
              ),
            ),
        ],
      ),
    ),
    ),
      if (isUser)
        Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 4.0),
          child: SvgPicture.string(
            userAvatarSvg,
            height: 32,
            width: 32,
          ),
        ),
    ],
    ),
    );
    },
    ),
    ),
      if (_isLoading)
        Container(
          padding: const EdgeInsets.all(12.0),
          margin: EdgeInsets.only(left: 56, bottom: 12, right: 60),
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(16),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A93D5)),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Thinking...',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(16),
              spreadRadius: 1,
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Microphone button for voice input
              GestureDetector(
                onTap: _startListening,
                child: Container(
                  margin: EdgeInsets.only(right: 8),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isListening
                          ? [Colors.red, Colors.redAccent]
                          : [Color(0xFF2A93D5).withAlpha(180), Color(0xFF37CAEC).withAlpha(180)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF2A93D5).withAlpha(64),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFF0F8FF),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey[800]! : Color(0xFFE1E8ED),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: _isListening ? "Listening..." : "Send a message...",
                            hintStyle: TextStyle(
                              color: _isListening
                                  ? (isDarkMode ? Colors.red[300] : Colors.red[400])
                                  : (isDarkMode ? Colors.grey[400] : Colors.grey[500]),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) {
                              sendMessage(text);
                            }
                          },
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return GestureDetector(
                            onTap: () {
                              final text = _controller.text.trim();
                              if (text.isNotEmpty) {
                                sendMessage(text);
                                _animationController.forward(from: 0.0);
                              }
                            },
                            child: Container(
                              margin: EdgeInsets.only(right: 6),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2A93D5), Color(0xFF37CAEC)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF2A93D5).withAlpha(64),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Transform.rotate(
                                angle: _animationController.value * 2.0 * 3.14159,
                                child: Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
    ),
      ),
    );
  }
}

String extractJson(String responseText) {
  final RegExp regex = RegExp(r'```json\s*([\s\S]*?)\s*```');
  final Match? match = regex.firstMatch(responseText);

  if (match != null) {
    return match.group(1)!; // Extract JSON string
  } else {
    // If no JSON block is found, try to find any JSON-like structure
    final jsonStart = responseText.indexOf('{');
    final jsonEnd = responseText.lastIndexOf('}');

    if (jsonStart != -1 && jsonEnd != -1 && jsonStart < jsonEnd) {
      return responseText.substring(jsonStart, jsonEnd + 1);
    }

    // If no JSON structure is found, create a default JSON response
    return '{"response": "I\'m having trouble processing your request. Could you try again?", "language": "english"}';
  }
}