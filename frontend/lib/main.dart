import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

// --- CONFIG & NETWORK ---
final apiBaseUrlProvider = Provider<String>((ref) => "http://127.0.0.1:9005/api");
final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: ref.read(apiBaseUrlProvider)));
  final storage = ref.read(secureStorageProvider);

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: "access_token");
      if (token != null) {
        options.headers["Authorization"] = "Bearer $token";
      }
      return handler.next(options);
    },
    onError: (e, handler) async {
      return handler.next(e);
    },
  ));
  return dio;
});

// --- STATE MANAGEMENT ---
class AuthState {
  final bool isAuthenticated;
  final String? userName;
  final String? userEmail;
  final String? errorMessage;
  final bool isLoading;

  AuthState({
    this.isAuthenticated = false,
    this.userName,
    this.userEmail,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userName,
    String? userEmail,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  Dio get _dio => ref.read(dioProvider);
  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  AuthState build() {
    Future.microtask(() => checkAuthStatus());
    return AuthState();
  }

  Future<void> checkAuthStatus() async {
    try {
      final token = await _storage.read(key: "access_token");
      if (token == null) {
        state = AuthState(isAuthenticated: false);
        return;
      }
      final res = await _dio.get("/user/profile");
      if (res.statusCode == 200) {
        state = AuthState(
          isAuthenticated: true,
          userName: res.data["name"],
          userEmail: res.data["email"],
        );
      }
    } catch (e) {
      try {
        await _storage.delete(key: "access_token");
        await _storage.delete(key: "refresh_token");
      } catch (_) {}
      state = AuthState(isAuthenticated: false);
    }
  }


  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _dio.post("/auth/login", data: {
        "email": email,
        "password": password,
      });
      final accessToken = res.data["access_token"];
      final refreshToken = res.data["refresh_token"];

      await _storage.write(key: "access_token", value: accessToken);
      await _storage.write(key: "refresh_token", value: refreshToken);

      // Fetch Profile details
      final profileRes = await _dio.get("/user/profile");
      state = AuthState(
        isAuthenticated: true,
        userName: profileRes.data["name"],
        userEmail: profileRes.data["email"],
      );
    } on DioException catch (e) {
      final msg = e.response?.data["detail"] ?? "Invalid email or password";
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _dio.post("/auth/register", data: {
        "name": name,
        "email": email,
        "password": password,
      });
      await login(email, password);
    } on DioException catch (e) {
      final msg = e.response?.data["detail"] ?? "Registration failed";
      state = state.copyWith(isLoading: false, errorMessage: msg);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post("/auth/logout");
    } catch (_) {}
    await _storage.delete(key: "access_token");
    await _storage.delete(key: "refresh_token");
    state = AuthState(isAuthenticated: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// --- CHAT SESSION MANAGEMENT ---
class ChatMessage {
  final String text;
  final String sender; // 'user' or 'ai'
  final DateTime timestamp;
  final bool isFollowUpPrompt;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isFollowUpPrompt = false,
  });
}

class ChatNotifier extends Notifier<List<ChatMessage>> {
  Dio get _dio => ref.read(dioProvider);
  String? activeSessionId;

  @override
  List<ChatMessage> build() {
    return [];
  }

  Future<void> startNewSession() async {
    state = [
      ChatMessage(
        text: "Hello! I'm Med Genie, your AI health assistant. How can I help you today? Please fill out your Health Info for personalized answers.",
        sender: 'ai',
        timestamp: DateTime.now(),
      )
    ];
    try {
      final res = await _dio.post("/chat/sessions", data: {"title": "New Chat Session"});
      activeSessionId = res.data["sessionId"];
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (activeSessionId == null) {
      await startNewSession();
    }
    
    final userMsg = ChatMessage(text: text, sender: 'user', timestamp: DateTime.now());
    state = [...state, userMsg];

    final thinkingMsg = ChatMessage(text: "Thinking...", sender: 'ai', timestamp: DateTime.now());
    state = [...state, thinkingMsg];

    try {
      final res = await _dio.post(
        "/chat/sessions/$activeSessionId/messages",
        data: {"content": text},
      );
      state = state.where((msg) => msg.text != "Thinking...").toList();
      
      final answer = res.data["answer"];
      final followUp = res.data["followUpQuestion"];

      state = [
        ...state,
        ChatMessage(text: answer, sender: 'ai', timestamp: DateTime.now())
      ];

      if (followUp != null && followUp.toString().isNotEmpty) {
        state = [
          ...state,
          ChatMessage(
            text: followUp,
            sender: 'ai',
            timestamp: DateTime.now(),
            isFollowUpPrompt: true,
          )
        ];
      }
    } catch (_) {
      state = state.where((msg) => msg.text != "Thinking...").toList();
      state = [
        ...state,
        ChatMessage(
          text: "Sorry, I encountered an issue. Please try again.",
          sender: 'ai',
          timestamp: DateTime.now(),
        )
      ];
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);

// --- ENTRY MAIN ---
void main() {
  runApp(const ProviderScope(child: MedGenieApp()));
}

class MedGenieApp extends ConsumerWidget {
  const MedGenieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Med Genie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // slate-900
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981), // Emerald primary
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
      ),
      home: authState.isAuthenticated ? const DashboardScreen() : const LandingScreen(),
    );
  }
}

// --- SCREENS ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer(
        builder: (context, ref, child) {
          final authState = ref.watch(authProvider);

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                color: const Color(0xFF1E293B), // slate-800
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "🩺 MED GENIE",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isLogin ? "Welcome back! Login to consult" : "Create a secure health account",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      if (authState.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(authState.errorMessage!, style: const TextStyle(color: Colors.red)),
                        ),
                      if (authState.errorMessage != null) const SizedBox(height: 16),
                      if (!isLogin) ...[
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: authState.isLoading
                              ? null
                              : () {
                                  if (isLogin) {
                                    ref.read(authProvider.notifier).login(_emailCtrl.text, _passwordCtrl.text);
                                  } else {
                                    ref.read(authProvider.notifier).register(
                                          _nameCtrl.text,
                                          _emailCtrl.text,
                                          _passwordCtrl.text,
                                        );
                                  }
                                },
                          child: authState.isLoading
                              ? const CircularProgressIndicator()
                              : Text(isLogin ? "Sign In" : "Register"),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isLogin = !isLogin;
                          });
                        },
                        child: Text(isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chatProvider.notifier).startNewSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatMessages = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Med Genie"),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.pinkAccent),
            tooltip: "Heart Risk Evaluator",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HeartRiskScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Update Vitals",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HealthProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Emergency Advice Panel
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.redAccent.withAlpha(38),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Med Genie provides general health info. For life-threatening emergencies, seek immediate clinical care.",
                    style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Chats feeds
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final msg = chatMessages[index];
                final isUser = msg.sender == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(color: isUser ? Colors.black : Colors.white),
                        ),
                        if (msg.isFollowUpPrompt) ...[
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const HealthProfileScreen()),
                              );
                            },
                            child: const Text("Provide Detail"),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Input Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: "Ask about symptoms, dosages...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF10B981),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Colors.black),
                    onPressed: () {
                      if (_msgCtrl.text.trim().isNotEmpty) {
                        ref.read(chatProvider.notifier).sendMessage(_msgCtrl.text);
                        _msgCtrl.clear();
                      }
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
}

// --- PROFILE EDIT SCREEN ---
class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  ConsumerState<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
  final _medHistory = TextEditingController();
  final _lifestyle = TextEditingController();
  final _symptoms = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ref.read(dioProvider).get("/user/profile");
      final profile = res.data["healthProfile"];
      _medHistory.text = profile["medicalHistory"] ?? "";
      _lifestyle.text = profile["lifestyle"] ?? "";
      _symptoms.text = profile["symptoms"] ?? "";
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await ref.read(dioProvider).put("/user/profile", data: {
        "medicalHistory": _medHistory.text,
        "lifestyle": _lifestyle.text,
        "symptoms": _symptoms.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Health Profile updated successfully")),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Personalized Vitals"), backgroundColor: const Color(0xFF1E293B)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  "Providing details helps Med Genie tailor suggestions to your body context.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _medHistory,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Medical History",
                    helperText: "e.g., Allergies, diagnosed asthma, chronic illnesses",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _lifestyle,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Lifestyle Factors",
                    helperText: "e.g., Diet, physical exercise, smoking status",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _symptoms,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Current Symptoms",
                    helperText: "e.g., Occasional headaches, cough duration",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text("Save Vitals"),
                  ),
                ),
              ],
            ),
    );
  }
}

// --- HEART RISK MODEL EVALUATOR ---
class HeartRiskScreen extends ConsumerStatefulWidget {
  const HeartRiskScreen({super.key});

  @override
  ConsumerState<HeartRiskScreen> createState() => _HeartRiskScreenState();
}

class _HeartRiskScreenState extends ConsumerState<HeartRiskScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Predictor vital variables
  int age = 45;
  int sex = 1; // Male
  int cp = 0;  // Chest pain
  int bp = 120; // Blood pressure
  int chol = 200; // Cholesterol
  int fbs = 0; // Fasting blood sugar
  int ecg = 0; // Resting ECG
  int thalach = 150; // Max HR
  int exang = 0; // Angina
  double oldpeak = 0.0;
  int slope = 1;

  bool _isLoading = false;
  double? _resultScore;
  String? _adviceText;

  Future<void> _evaluateRisk() async {
    setState(() {
      _isLoading = true;
      _resultScore = null;
    });
    try {
      final res = await ref.read(dioProvider).post("/risk/predict", data: {
        "age": age,
        "sex": sex,
        "chest_pain_type": cp,
        "resting_bp": bp,
        "cholesterol": chol,
        "fasting_blood_sugar": fbs,
        "resting_ecg": ecg,
        "max_heart_rate": thalach,
        "exercise_angina": exang,
        "oldpeak": oldpeak,
        "st_slope": slope
      });
      setState(() {
        _resultScore = res.data["risk_probability"] * 100;
        _adviceText = res.data["risk_predicted"] == 1 
            ? "WARNING: Model predicts an elevated risk of coronary event. Please review with a cardiologist."
            : "INFO: Model predicts risk indicators within standard parameters. Continue maintaining healthy vitals.";
      });
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cardiac Risk Evaluator"), backgroundColor: const Color(0xFF1E293B)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _resultScore != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${_resultScore!.toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 84, 
                        fontWeight: FontWeight.bold, 
                        color: _resultScore! > 50 ? Colors.redAccent : const Color(0xFF10B981)
                      ),
                    ),
                    const Text("Calculated Heart Risk Score", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Text(
                        _adviceText!, 
                        style: const TextStyle(height: 1.5, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _resultScore = null;
                        });
                      }, 
                      child: const Text("Test Again")
                    )
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text("Input patient indicators to run ML Heart Risk Prediction:"),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: age.toString(),
                      decoration: const InputDecoration(labelText: "Age"),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => age = int.tryParse(v) ?? age,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: sex,
                      decoration: const InputDecoration(labelText: "Sex"),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text("Male")),
                        DropdownMenuItem(value: 0, child: Text("Female")),
                      ],
                      onChanged: (v) => setState(() => sex = v ?? sex),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: bp.toString(),
                      decoration: const InputDecoration(labelText: "Resting Blood Pressure (mm Hg)"),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => bp = int.tryParse(v) ?? bp,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: chol.toString(),
                      decoration: const InputDecoration(labelText: "Serum Cholesterol (mg/dl)"),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => chol = int.tryParse(v) ?? chol,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: thalach.toString(),
                      decoration: const InputDecoration(labelText: "Maximum Heart Rate Achieved"),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => thalach = int.tryParse(v) ?? thalach,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: cp,
                      decoration: const InputDecoration(labelText: "Chest Pain Type"),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text("Typical Angina")),
                        DropdownMenuItem(value: 1, child: Text("Atypical Angina")),
                        DropdownMenuItem(value: 2, child: Text("Non-anginal Pain")),
                        DropdownMenuItem(value: 3, child: Text("Asymptomatic")),
                      ],
                      onChanged: (v) => setState(() => cp = v ?? cp),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: _evaluateRisk,
                      child: const Text("Predict Heart Risk"),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}

// --- LANDING SCREEN ---
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _emailCtrl = TextEditingController();
  bool _subscribed = false;
  final _newsletterFormKey = GlobalKey<FormState>();

  // FAQ expanded state tracking
  final Map<int, bool> _faqExpanded = {
    0: false,
    1: false,
    2: false,
    3: false,
    4: false,
    5: false,
  };

  void _subscribeNewsletter() {
    if (_newsletterFormKey.currentState!.validate()) {
      setState(() {
        _subscribed = true;
      });
      _emailCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Subscription successful! Check your inbox for updates.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header / Navbar
            _buildNavbar(isDesktop),
            // Hero Section
            _buildHero(isDesktop),
            // How Med Genie Helps You Section
            _buildFeatures(isDesktop),
            // Guide to MedGenie / Cards
            _buildGuide(isDesktop),
            // FAQs Accordion
            _buildFaqs(),
            // Footer
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.only(top: 24, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.25)), // border: #3FB5F440
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                "🩺 MedGenie",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (isDesktop)
            Row(
              children: [
                _buildNavLink("About Us"),
                const SizedBox(width: 24),
                _buildNavLink("Services"),
                const SizedBox(width: 24),
                _buildNavLink("Our Process"),
                const SizedBox(width: 24),
                _buildNavLink("Find Specialist"),
                const SizedBox(width: 24),
                _buildNavLink("FAQ"),
              ],
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6), // #3FB5F4
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
            },
            child: const Text(
              "Login",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLink(String title) {
    return InkWell(
      onTap: () {
        // Simple scroll or action placeholder
      },
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFFADADAD), fontSize: 16),
      ),
    );
  }

  Widget _buildHero(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const Text(
                "Your AI-powered Health Companion",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF3B82F6)], // Emerald to Blue gradient
                ).createShader(bounds),
                child: const Text(
                  "MedGenie – Care at Your Fingertips",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white, // masked
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "MedGenie is your smart AI health assistant — get instant answers to basic medical questions, emergency guidance, and symptom-based suggestions. Privacy-first, accessible anywhere, anytime.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF939393), fontSize: 18, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // #3FB5F4 -> Emerald style
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  minimumSize: const Size(200, 50),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthScreen()));
                },
                child: const Text(
                  "Try MedGenie",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Helping users during health emergencies, trusted by the open-source community",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF939393), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatures(bool isDesktop) {
    final features = [
      {
        "icon": Icons.message,
        "title": "Conversational AI",
        "desc": "Chat naturally with an AI trained on health-related queries to get instant, reliable answers for common symptoms and medical concerns."
      },
      {
        "icon": Icons.emergency,
        "title": "Emergency Assistance",
        "desc": "Quickly access nearby hospital guidance, emergency numbers, and first-aid tips when time matters most."
      },
      {
        "icon": Icons.healing,
        "title": "Symptom Checker",
        "desc": "Describe your symptoms and get possible condition suggestions, empowering you with actionable health insights."
      },
      {
        "icon": Icons.mic,
        "title": "Voice Input",
        "desc": "Speak directly to Med Genie using built-in speech recognition for quick, hands-free health assistance."
      },
      {
        "icon": Icons.dark_mode,
        "title": "Theme Toggle",
        "desc": "Switch between dark and light modes for a comfortable experience in any environment."
      },
      {
        "icon": Icons.security,
        "title": "Privacy-First",
        "desc": "No data storage or tracking — your health queries remain private and secure."
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          const Text(
            "How Med Genie Helps You",
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, index) {
              final f = features[index];
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.05),
                      blurRadius: 20,
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(f["icon"] as IconData, color: const Color(0xFF3B82F6), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            f["title"] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Text(
                        f["desc"] as String,
                        style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGuide(bool isDesktop) {
    final guides = [
      {"title": "Chat Naturally with AI", "desc": "Ask MedGenie your health-related queries in a conversational way. Get instant guidance without jargon."},
      {"title": "Emergency Assistance", "desc": "Quickly access hospital info and emergency numbers when you need them the most."},
      {"title": "Symptom Checker", "desc": "Describe your symptoms and get AI-suggested possible conditions instantly."},
      {"title": "Voice Input", "desc": "Prefer talking instead of typing? Use the built-in speech recognition for hands-free interaction."},
      {"title": "Dark/Light Mode", "desc": "Switch between light and dark themes for better comfort, day or night."},
      {"title": "Privacy First", "desc": "We don’t store your data. Your conversations stay private between you and MedGenie."},
      {"title": "Upcoming: AI Diagnosis Engine", "desc": "Soon, MedGenie will predict health issues using advanced AI-driven analysis."},
      {"title": "Upcoming: Location-based Assistance", "desc": "Find nearby hospitals, clinics, and pharmacies with smart location integration."},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      color: Colors.black.withOpacity(0.1),
      child: Column(
        children: [
          const Text(
            "Your Guide to MedGenie",
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Discover how MedGenie can assist you with health queries, emergencies, and upcoming smart features.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: guides.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isDesktop ? 3.5 : 2.5,
            ),
            itemBuilder: (context, index) {
              final g = guides[index];
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF3B82F6), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g["title"]!,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              g["desc"]!,
                              style: const TextStyle(color: Color(0xFFADADAD), fontSize: 13, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFaqs() {
    final faqs = [
      {
        "q": "What is Med Genie?",
        "a": "Med Genie is an AI-powered health assistant that helps you with basic medical queries, emergency guidance, and symptom-based suggestions — all through natural conversation."
      },
      {
        "q": "Is Med Genie a replacement for a doctor?",
        "a": "No. Med Genie is designed for basic guidance and quick information. It does not replace professional medical advice, diagnosis, or treatment. Always consult a qualified doctor for medical concerns."
      },
      {
        "q": "Does Med Genie store my data?",
        "a": "No. Med Genie is privacy-first — it does not store, track, or share any personal health data."
      },
      {
        "q": "Can Med Genie help in emergencies?",
        "a": "Yes. Med Genie can provide you with emergency contact numbers, hospital information, and basic first-aid tips, but it cannot replace urgent medical services. Always call emergency services if needed."
      },
      {
        "q": "What features does Med Genie offer?",
        "a": "You can chat in multiple languages, check symptoms, get health tips, use voice input, and toggle between dark/light themes for better accessibility."
      },
      {
        "q": "Is Med Genie free to use?",
        "a": "Yes! Med Genie is free for everyone. All features are available without any subscription or hidden costs."
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          const Text(
            "Frequently Asked Questions",
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: faqs.length,
            itemBuilder: (context, index) {
              final faq = faqs[index];
              final expanded = _faqExpanded[index] ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        faq["q"]!,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(
                        expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      onTap: () {
                        setState(() {
                          _faqExpanded[index] = !expanded;
                        });
                      },
                    ),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            faq["a"]!,
                            style: const TextStyle(color: Color(0xFFADADAD), fontSize: 14, height: 1.4),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)], // Sky Blue to Cyan
        ),
      ),
      child: Column(
        children: [
          // Newsletter Form
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Form(
              key: _newsletterFormKey,
              child: Flex(
                direction: isDesktop ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "Stay Updated with Health Insights",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Subscribe to our newsletter for the latest health tips and AI updates.",
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16, width: 16),
                  if (_subscribed)
                    const Text(
                      "Subscribed Successfully!",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 250,
                          child: TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || !v.contains("@")) return "Enter valid email";
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: "Enter your email",
                              fillColor: Colors.white.withOpacity(0.9),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0EA5E9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: _subscribeNewsletter,
                          child: const Text("Subscribe", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            "MedGenie",
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "The Future of Healthcare Collaboration",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFooterLink("Privacy Policy"),
              const SizedBox(width: 16),
              _buildFooterLink("Terms of Use"),
              const SizedBox(width: 16),
              _buildFooterLink("Cookie Policy"),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          const Text(
            "© 2026 MedGenie. All Rights Reserved.",
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String title) {
    return InkWell(
      onTap: () {},
      child: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 13, decoration: TextDecoration.underline),
      ),
    );
  }
}
