import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/medical_disclaimer_banner.dart';

class HealthProfileScreen extends ConsumerStatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  ConsumerState<HealthProfileScreen> createState() =>
      _HealthProfileScreenState();
}

class _HealthProfileScreenState extends ConsumerState<HealthProfileScreen> {
  final _medHistory = TextEditingController();
  final _lifestyle = TextEditingController();
  final _symptoms = TextEditingController();
  final _allergies = TextEditingController();
  final _medications = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _medHistory.dispose();
    _lifestyle.dispose();
    _symptoms.dispose();
    _allergies.dispose();
    _medications.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(dioProvider).get("/user/profile");
      final profile = res.data["healthProfile"];
      _medHistory.text = profile["medicalHistory"] ?? "";
      _lifestyle.text = profile["lifestyle"] ?? "";
      _symptoms.text = profile["symptoms"] ?? "";
      _allergies.text = profile["allergies"] ?? "";
      _medications.text = profile["medications"] ?? "";
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(dioProvider).put("/user/profile", data: {
        "medicalHistory": _medHistory.text,
        "lifestyle": _lifestyle.text,
        "symptoms": _symptoms.text,
        "allergies": _allergies.text,
        "medications": _medications.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                SizedBox(width: 10),
                Text("Health profile updated successfully"),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save profile. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Personalized Vitals"),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined,
                      color: Color(0xFF10B981), size: 18),
              label: const Text("Save",
                  style: TextStyle(color: Color(0xFF10B981))),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView(message: "Loading profile...")
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info banner
                MedicalDisclaimerBanner(
                  message: "Providing your health context helps Wellness give more personalized and relevant responses.",
                  icon: Icons.info_outline,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 24),

                _buildSection(
                  icon: Icons.history,
                  label: "Medical History",
                  helper:
                      "e.g., Allergies, diagnosed conditions, chronic illnesses",
                  controller: _medHistory,
                ),
                const SizedBox(height: 20),

                _buildSection(
                  icon: Icons.directions_run,
                  label: "Lifestyle Factors",
                  helper: "e.g., Diet, exercise habits, smoking status",
                  controller: _lifestyle,
                ),
                const SizedBox(height: 20),

                _buildSection(
                  icon: Icons.sick_outlined,
                  label: "Current Symptoms",
                  helper: "e.g., Occasional headaches, persistent cough",
                  controller: _symptoms,
                ),
                const SizedBox(height: 20),

                _buildSection(
                  icon: Icons.warning_amber_outlined,
                  label: "Allergies",
                  helper: "e.g., Penicillin, latex, peanuts",
                  controller: _allergies,
                ),
                const SizedBox(height: 20),

                _buildSection(
                  icon: Icons.medication_outlined,
                  label: "Current Medications",
                  helper: "e.g., Metformin 500mg, Albuterol inhaler",
                  controller: _medications,
                ),
                const SizedBox(height: 36),

                AppButton(
                  text: "Save Vitals",
                  isLoading: _isSaving,
                  onPressed: _saveProfile,
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String label,
    required String helper,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            helperText: helper,
            helperStyle:
                TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

