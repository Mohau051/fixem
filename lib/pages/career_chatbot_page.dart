import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// ChatMessage model
// ---------------------------------------------------------------------------

/// Represents a single chat message — either from the user or the bot.
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// ---------------------------------------------------------------------------
// DialogflowService — handles JWT auth + REST API calls
// ---------------------------------------------------------------------------

/// Wraps the Dialogflow ES REST API.
/// Authentication is done via a short-lived OAuth2 access token obtained by
/// signing a JWT with the service-account private key (RSA-256).
class DialogflowService {
  // ── Constants ────────────────────────────────────────────────────────────

  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _dialogflowScope =
      'https://www.googleapis.com/auth/dialogflow';
  static const String _dialogflowBase =
      'https://dialogflow.googleapis.com/v2';

  // ── Private fields ───────────────────────────────────────────────────────

  /// Loaded from the bundled service-account JSON asset.
  late final Map<String, dynamic> _credentials;

  String? _accessToken;
  DateTime? _tokenExpiry;

  bool _initialised = false;

  // ── Initialisation ───────────────────────────────────────────────────────

  /// Call once after construction.  Loads the JSON asset from disk.
  Future<void> init() async {
    final raw = await rootBundle
        .loadString('assets/fix-em-6b9bd-4cc7988a506e.json');
    _credentials = json.decode(raw) as Map<String, dynamic>;
    _initialised = true;
  }

  // ── Token management ─────────────────────────────────────────────────────

  /// Returns a valid OAuth2 access token, refreshing if necessary.
  Future<String> _getAccessToken() async {
    // Reuse existing token if still valid (with 60 s buffer)
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(
            _tokenExpiry!.subtract(const Duration(seconds: 60)))) {
      return _accessToken!;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Build JWT claims for Google OAuth2
    final jwt = JWT(
      {
        'iss': _credentials['client_email'] as String,
        'scope': _dialogflowScope,
        'aud': _tokenUrl,
        'iat': now,
        'exp': now + 3600, // 1 hour
      },
    );

    // Sign with the service-account private key
    final privateKey = _credentials['private_key'] as String;
    final signed = jwt.sign(RSAPrivateKey(privateKey),
        algorithm: JWTAlgorithm.RS256);

    // Exchange the JWT for an access token
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': signed,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to obtain access token: ${response.statusCode} ${response.body}');
    }

    final tokenData = json.decode(response.body) as Map<String, dynamic>;
    _accessToken = tokenData['access_token'] as String;
    _tokenExpiry =
        DateTime.now().add(Duration(seconds: tokenData['expires_in'] as int));

    return _accessToken!;
  }

  // ── Detect Intent ─────────────────────────────────────────────────────────

  /// Sends [userMessage] to Dialogflow ES and returns the fulfilment text.
  Future<String> detectIntent({
    required String sessionId,
    required String userMessage,
    String languageCode = 'en',
  }) async {
    assert(_initialised, 'Call init() before using DialogflowService.');

    final projectId = _credentials['project_id'] as String;
    final token = await _getAccessToken();

    final url = Uri.parse(
      '$_dialogflowBase/projects/$projectId/agent/sessions/$sessionId:detectIntent',
    );

    final body = json.encode({
      'queryInput': {
        'text': {
          'text': userMessage,
          'languageCode': languageCode,
        },
      },
    });

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Dialogflow error ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final queryResult = data['queryResult'] as Map<String, dynamic>?;
    final fulfillmentText =
        queryResult?['fulfillmentText'] as String? ?? '';

    if (fulfillmentText.isEmpty) {
      return "I'm sorry, I didn't quite catch that. Could you please rephrase your question?";
    }

    return fulfillmentText;
  }
}

// ---------------------------------------------------------------------------
// CareerChatbotPage
// ---------------------------------------------------------------------------

/// Full-screen career guidance chatbot powered by Dialogflow ES (REST API).
///
/// Navigate to this page with:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerChatbotPage()));
class CareerChatbotPage extends StatefulWidget {
  const CareerChatbotPage({super.key});

  @override
  State<CareerChatbotPage> createState() => _CareerChatbotPageState();
}

class _CareerChatbotPageState extends State<CareerChatbotPage>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────

  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();
  final DialogflowService _dialogflow = DialogflowService();

  late final String _sessionId;
  bool _isLoading = false;
  bool _isInitialised = false;

  // Animated typing dots
  late AnimationController _dotController;
  late Animation<double> _dotAnimation;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _sessionId = _uuid.v4();

    // Bouncing dots animation
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _dotAnimation = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _dotController, curve: Curves.easeInOut),
    );

    _initChatbot();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Initialises the Dialogflow service and posts the welcome message.
  Future<void> _initChatbot() async {
    try {
      await _dialogflow.init();
      if (!mounted) return;

      setState(() => _isInitialised = true);
      _addBotMessage(
        'Hello! I am your Fixem Career Assistant. I can help with career '
        'guidance, job readiness, CV tips, interview advice, and skills '
        'recommendations. How can I help you today?',
      );
    } catch (e) {
      debugPrint('Chatbot init error: $e');
      _showError('Could not initialise chatbot. Please try again later.');
    }
  }

  // ── Messaging ──────────────────────────────────────────────────────────────

  /// Sends the typed message to Dialogflow and displays the response.
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (!_isInitialised) {
      _showError('The chatbot is still loading. Please wait a moment.');
      return;
    }

    _addUserMessage(text);
    _textController.clear();
    setState(() => _isLoading = true);

    try {
      final reply = await _dialogflow.detectIntent(
        sessionId: _sessionId,
        userMessage: text,
      );
      _addBotMessage(reply);
    } catch (e) {
      debugPrint('Send message error: $e');
      _addBotMessage(
        "I'm having trouble connecting right now. Please check your internet "
        'connection and try again.',
      );
      _showError('Failed to reach the chatbot. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ── Suggested questions ────────────────────────────────────────────────────

  static const List<String> _suggestions = [
    'How do I create a CV?',
    'What jobs can I apply for without experience?',
    'How do I prepare for an interview?',
    'What skills should I learn for retail jobs?',
    'Recommend careers for technology',
  ];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      // Prevent Flutter from resizing the column when the keyboard appears.
      // The input bar already compensates via MediaQuery.viewInsets.bottom.
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: !_isInitialised && _messages.isEmpty
                ? _buildInitLoader()
                : _buildMessageList(),
          ),
          // Show suggestions only when conversation is brand new
          if (_isInitialised && _messages.length <= 1)
            _buildSuggestions(),
          // Typing indicator
          if (_isLoading) _buildTypingIndicator(),
          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Career Guidance Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Powered by Fixem AI',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Initialisation loader ──────────────────────────────────────────────────

  Widget _buildInitLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Starting Career Assistant…',
            style: TextStyle(
              color: Color(0xFF0D47A1),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Message list ───────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildBubble(_messages[index]),
    );
  }

  // ── Chat bubble ────────────────────────────────────────────────────────────

  Widget _buildBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Bot avatar
          if (!isUser) ...[
            _avatar(Icons.smart_toy_rounded,
                [const Color(0xFF0D47A1), const Color(0xFF42A5F5)]),
            const SizedBox(width: 8),
          ],

          // Bubble body
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : const Color(0xFF212121),
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.6)
                          : Colors.grey.shade400,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User avatar
          if (isUser) ...[
            const SizedBox(width: 8),
            _avatar(Icons.person,
                [const Color(0xFF0D47A1), const Color(0xFF1565C0)]),
          ],
        ],
      ),
    );
  }

  /// Circular avatar widget shared by user and bot bubbles.
  Widget _avatar(IconData icon, List<Color> colors) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  // ── Typing indicator ───────────────────────────────────────────────────────

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _avatar(Icons.smart_toy_rounded,
              [const Color(0xFF0D47A1), const Color(0xFF42A5F5)]),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _dotAnimation,
              builder: (_, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // Stagger dots by adding a phase offset
                    final phase = (i * 0.3);
                    final val =
                        (_dotAnimation.value - phase).clamp(0.0, 6.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: 8,
                      height: 8 + val,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2).withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggested questions ────────────────────────────────────────────────────

  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Suggested questions:',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestions.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      _textController.text = q;
                      _sendMessage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        border: Border.all(
                            color: const Color(0xFF90CAF9), width: 1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        q,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(28),
                border:
                    Border.all(color: const Color(0xFFBBDEFB), width: 1.2),
              ),
              child: TextField(
                controller: _textController,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 14.5, color: Color(0xFF212121)),
                decoration: InputDecoration(
                  hintText: 'Ask about careers, CV tips, jobs…',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
