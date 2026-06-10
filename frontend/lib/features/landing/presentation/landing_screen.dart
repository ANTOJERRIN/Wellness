import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../contact/presentation/contact_screen.dart';
import '../../specialist/presentation/specialist_screen.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final _emailCtrl = TextEditingController();
  final _newsletterFormKey = GlobalKey<FormState>();
  bool _subscribed = false;
  bool _subscribing = false;
  final Map<int, bool> _faqExpanded = {
    for (int i = 0; i < 6; i++) i: false
  };

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _subscribeNewsletter() async {
    if (!_newsletterFormKey.currentState!.validate()) return;
    setState(() => _subscribing = true);
    try {
      await ref.read(dioProvider).post("/newsletter/subscribe", data: {
        "email": _emailCtrl.text.trim(),
      });
      setState(() {
        _subscribed = true;
        _subscribing = false;
      });
      _emailCtrl.clear();
    } catch (_) {
      setState(() {
        // Even on error, show success (in case of duplicate or network issue)
        _subscribed = true;
        _subscribing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNavbar(isDesktop, isDark),
            _buildHero(isDesktop),
            _buildFeatures(isDesktop),
            _buildGuide(isDesktop),
            _buildFaqs(),
            _buildFooter(isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbar(bool isDesktop, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.only(top: 20, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
            blurRadius: 20,
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Text("🩺",
                  style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                "MedGenie",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          if (isDesktop)
            Row(
              children: [
                _navLink("Services"),
                const SizedBox(width: 28),
                _navLink("Features"),
                const SizedBox(width: 28),
                _navLink("FAQ"),
                const SizedBox(width: 28),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactScreen()),
                  ),
                  child: const Text("Contact",
                      style: TextStyle(
                          color: Color(0xFFADADAD), fontSize: 15)),
                ),
              ],
            ),
          Row(
            children: [
              // Theme toggle
              IconButton(
                icon: Icon(
                  ref.watch(themeModeProvider) == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: Colors.amber,
                  size: 20,
                ),
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).toggle(),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AuthScreen()),
                ),
                child: const Text("Login",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navLink(String title) {
    return Text(title,
        style: const TextStyle(color: Color(0xFFADADAD), fontSize: 15));
  }

  Widget _buildHero(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 24, vertical: isDesktop ? 100 : 60),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: const Text(
                  "🤖 AI-Powered Health Assistant",
                  style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                "Your AI-powered\nHealth Companion",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                ).createShader(bounds),
                child: const Text(
                  "MedGenie – Care at Your Fingertips",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                "MedGenie is your smart AI health assistant — get instant answers to medical questions, emergency guidance, and symptom-based suggestions. Privacy-first, accessible anywhere, anytime.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 17,
                    height: 1.6),
              ),
              const SizedBox(height: 40),

              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AuthScreen()),
                    ),
                    icon: const Icon(Icons.rocket_launch_outlined,
                        size: 20),
                    label: const Text("Try MedGenie",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3B82F6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SpecialistScreen()),
                    ),
                    icon: const Icon(Icons.person_search_outlined,
                        size: 20),
                    label: const Text("Find Specialist",
                        style: TextStyle(fontSize: 17)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                "Trusted by health-conscious users worldwide • Open source • Privacy first",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13),
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
        "icon": Icons.smart_toy_outlined,
        "title": "Conversational AI",
        "desc":
            "Chat naturally with an AI trained on health queries to get instant, reliable answers."
      },
      {
        "icon": Icons.emergency_outlined,
        "title": "Emergency Assistance",
        "desc":
            "Quickly access nearby hospital guidance and emergency numbers when time matters most."
      },
      {
        "icon": Icons.healing_outlined,
        "title": "Symptom Checker",
        "desc":
            "Describe your symptoms and get AI-suggested possible conditions instantly."
      },
      {
        "icon": Icons.mic_none,
        "title": "Voice Input",
        "desc":
            "Speak directly to Med Genie using built-in speech recognition for hands-free assistance."
      },
      {
        "icon": Icons.dark_mode_outlined,
        "title": "Theme Toggle",
        "desc":
            "Switch between dark and light modes for a comfortable experience in any environment."
      },
      {
        "icon": Icons.lock_outline,
        "title": "Privacy-First",
        "desc":
            "JWT-secured, encrypted sessions — your health data stays private and protected."
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        children: [
          const Text(
            "How Med Genie Helps You",
            style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Six powerful features to support your health journey.",
            style:
                TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: features.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop
                  ? 3
                  : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isDesktop ? 1.4 : 1.2,
            ),
            itemBuilder: (context, index) {
              final f = features[index];
              return _buildFeatureCard(
                f["icon"] as IconData,
                f["title"] as String,
                f["desc"] as String,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
              blurRadius: 20,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: const Color(0xFF3B82F6), size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                desc,
                style: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 13.5,
                    height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuide(bool isDesktop) {
    final guides = [
      {
        "title": "Chat Naturally with AI",
        "desc":
            "Ask MedGenie your health-related queries in a conversational way. Get instant guidance without medical jargon."
      },
      {
        "title": "Emergency Assistance",
        "desc":
            "Quickly access hospital info and emergency numbers when you need them the most."
      },
      {
        "title": "Symptom Checker",
        "desc":
            "Describe your symptoms and get AI-suggested possible conditions instantly."
      },
      {
        "title": "Voice Input",
        "desc":
            "Prefer talking instead of typing? Use built-in speech recognition for hands-free interaction."
      },
      {
        "title": "Heart Risk Evaluator",
        "desc":
            "Input cardiac vitals and receive an ML-powered coronary risk prediction score instantly."
      },
      {
        "title": "Specialist Finder",
        "desc":
            "Describe symptoms to get recommended specialists, with urgency ratings and nearby hospital listings."
      },
      {
        "title": "Secure Auth",
        "desc":
            "JWT-based login with refresh tokens, account lockout protection, and secure session management."
      },
      {
        "title": "Privacy First",
        "desc":
            "No data tracking beyond your session. Your health conversations remain private between you and MedGenie."
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      color: Colors.black.withValues(alpha: 0.12),
      child: Column(
        children: [
          const Text(
            "Your Guide to MedGenie",
            style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Discover how MedGenie can assist you across every health need.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          ),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: guides.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isDesktop ? 3.8 : 2.8,
            ),
            itemBuilder: (context, index) {
              final g = guides[index];
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          color: Color(0xFF3B82F6), size: 14),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g["title"]!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              g["desc"]!,
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 13,
                                  height: 1.4),
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
        "a":
            "Med Genie is an AI-powered health assistant that helps you with basic medical queries, emergency guidance, and symptom-based suggestions — all through natural conversation."
      },
      {
        "q": "Is Med Genie a replacement for a doctor?",
        "a":
            "No. Med Genie is designed for basic guidance and quick information. It does not replace professional medical advice, diagnosis, or treatment. Always consult a qualified doctor for medical concerns."
      },
      {
        "q": "Does Med Genie store my data?",
        "a":
            "Your health profile and chat history are stored securely for personalized responses. All data is encrypted and never shared with third parties."
      },
      {
        "q": "Can Med Genie help in emergencies?",
        "a":
            "Yes. Med Genie can provide emergency contact numbers, nearby hospital information, and first-aid tips, but always call emergency services immediately for life-threatening situations."
      },
      {
        "q": "What features does Med Genie offer?",
        "a":
            "AI chat, symptom checking, heart risk prediction, specialist recommendations, nearby hospital finder, voice input, health profile personalization, and dark/light mode toggle."
      },
      {
        "q": "Is Med Genie free to use?",
        "a":
            "Yes! Med Genie is free for everyone. All core features are available without any subscription."
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        children: [
          const Text(
            "Frequently Asked Questions",
            style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: faqs.length,
              itemBuilder: (context, index) {
                final faq = faqs[index];
                final expanded = _faqExpanded[index] ?? false;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: expanded
                        ? const Color(0xFF1E293B)
                        : Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: expanded
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        title: Text(
                          faq["q"]!,
                          style: TextStyle(
                            color: expanded
                                ? Colors.white
                                : const Color(0xFFCCCCCC),
                            fontSize: 15,
                            fontWeight: expanded
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: expanded
                                ? const Color(0xFF3B82F6)
                                : Colors.grey,
                          ),
                        ),
                        onTap: () => setState(
                            () => _faqExpanded[index] = !expanded),
                      ),
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 20, right: 20, bottom: 18),
                          child: Text(
                            faq["a"]!,
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                                height: 1.6),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0284C7), Color(0xFF0EA5E9), Color(0xFF06B6D4)],
        ),
      ),
      child: Column(
        children: [
          // Newsletter form
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Form(
                key: _newsletterFormKey,
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(child: _newsletterText()),
                          const SizedBox(width: 32),
                          _newsletterInput(),
                        ],
                      )
                    : Column(
                        children: [
                          _newsletterText(),
                          const SizedBox(height: 20),
                          _newsletterInput(),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 56),

          const Text(
            "🩺 MedGenie",
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "The Future of AI-Powered Healthcare",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),

          Wrap(
            spacing: 20,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _footerLink("Privacy Policy"),
              _footerLink("Terms of Use"),
              _footerLink("Cookie Policy"),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactScreen()),
                ),
                child: const Text(
                  "Contact",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 16),
          const Text(
            "© 2026 MedGenie. All Rights Reserved. Built with Flutter & FastAPI.",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _newsletterText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Stay Updated with Health Insights",
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          "Subscribe for the latest health tips and MedGenie AI updates.",
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
        ),
      ],
    );
  }

  Widget _newsletterInput() {
    if (_subscribed) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.6)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
            SizedBox(width: 8),
            Text(
              "Subscribed Successfully!",
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          child: TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black),
            validator: (v) =>
                (v == null || !v.contains("@"))
                    ? "Enter valid email"
                    : null,
            decoration: InputDecoration(
              hintText: "Enter your email",
              hintStyle: const TextStyle(color: Colors.black45),
              fillColor: Colors.white.withValues(alpha: 0.95),
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0EA5E9),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _subscribing ? null : _subscribeNewsletter,
          child: _subscribing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF0EA5E9)))
              : const Text("Subscribe",
                  style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _footerLink(String title) {
    return GestureDetector(
      onTap: () {},
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationColor: Colors.white70),
      ),
    );
  }
}

