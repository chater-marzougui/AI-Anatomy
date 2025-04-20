import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
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
            title: 'Flamme Bleue',
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

    // Initialize speech recognition
    _initSpeech();

    // Initialize text to speech
    _initTts();
    // Add a welcome message when the app starts
    _addMessage("Hi there! I'm ${projectInfo['name']}, your assistant. How are you feeling today?", false);
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
    throw Exception("JSON block not found in the response");
  }
}
