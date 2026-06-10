import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/medical_disclaimer_banner.dart';
import '../../../core/constants/app_text.dart';

class HeartRiskScreen extends ConsumerStatefulWidget {
  const HeartRiskScreen({super.key});

  @override
  ConsumerState<HeartRiskScreen> createState() => _HeartRiskScreenState();
}

class _HeartRiskScreenState extends ConsumerState<HeartRiskScreen> {
  final _formKey = GlobalKey<FormState>();

  // Feature variables
  int age = 45;
  int sex = 1;
  int cp = 0;
  int bp = 120;
  int chol = 200;
  int fbs = 0;
  int ecg = 0;
  int thalach = 150;
  int exang = 0;
  double oldpeak = 0.0;
  int slope = 1;

  bool _isLoading = false;
  double? _resultScore;
  int? _resultClass;
  String? _engineUsed;

  Future<void> _evaluateRisk() async {
    if (!_formKey.currentState!.validate()) return;
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
        "st_slope": slope,
      });
      setState(() {
        _resultScore = (res.data["risk_probability"] as num).toDouble() * 100;
        _resultClass = res.data["risk_predicted"];
        _engineUsed = res.data["engine"];
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to get prediction. Check your connection."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cardiac Risk Evaluator"),
        actions: [
          if (_resultScore != null)
            TextButton(
              onPressed: () => setState(() {
                _resultScore = null;
                _resultClass = null;
              }),
              child: const Text("Re-test",
                  style: TextStyle(color: Color(0xFF10B981))),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView(message: "Analyzing cardiac indicators...")
          : _resultScore != null
              ? _buildResults()
              : _buildForm(),
    );
  }

  Widget _buildResults() {
    final isHighRisk = _resultClass == 1;
    final color =
        isHighRisk ? Colors.redAccent : const Color(0xFF10B981);
    final percentage = _resultScore!.toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Score dial
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 5),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "$percentage%",
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Cardiac Risk Probability",
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 16),
                ),
                const SizedBox(height: 20),
                // Risk level badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHighRisk
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isHighRisk ? "ELEVATED RISK" : "NORMAL RANGE",
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Advice card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medical_information,
                        color: Color(0xFF3B82F6), size: 20),
                    SizedBox(width: 10),
                    Text("Clinical Guidance",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isHighRisk
                      ? "The model predicts elevated cardiac risk indicators. This may indicate coronary artery disease or other cardiovascular conditions. We strongly recommend consulting a cardiologist for a full diagnostic evaluation including ECG and blood panel."
                      : "The model predicts that your indicators are within normal ranges. Continue maintaining a heart-healthy lifestyle with regular exercise, balanced diet, and routine check-ups.",
                  style: TextStyle(
                      color: Colors.grey.shade300,
                      height: 1.6,
                      fontSize: 14),
                ),
                if (_engineUsed != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Engine: ${_engineUsed!.replaceAll('_', ' ')}",
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Disclaimer
          MedicalDisclaimerBanner(
            message: AppText.fallbackDisclaimer,
            color: Colors.orange,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 24),

          AppButton(
            text: "Run Another Test",
            onPressed: () => setState(() {
              _resultScore = null;
              _resultClass = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          MedicalDisclaimerBanner(
            message: "Input your clinical indicators to run an ML-powered cardiac risk assessment.",
            color: Colors.pinkAccent,
            icon: Icons.favorite,
          ),
          const SizedBox(height: 24),

          _buildNumericField("Age (years)", age, 1, 120,
              (v) => setState(() => age = v)),
          _buildDropdown("Sex", sex, const {1: "Male", 0: "Female"},
              (v) => setState(() => sex = v!)),
          _buildDropdown(
            "Chest Pain Type",
            cp,
            const {
              0: "Typical Angina",
              1: "Atypical Angina",
              2: "Non-anginal Pain",
              3: "Asymptomatic",
            },
            (v) => setState(() => cp = v!),
          ),
          _buildNumericField("Resting Blood Pressure (mmHg)", bp, 50, 250,
              (v) => setState(() => bp = v)),
          _buildNumericField("Serum Cholesterol (mg/dl)", chol, 100, 600,
              (v) => setState(() => chol = v)),
          _buildDropdown(
            "Fasting Blood Sugar",
            fbs,
            const {0: "≤ 120 mg/dl (Normal)", 1: "> 120 mg/dl (High)"},
            (v) => setState(() => fbs = v!),
          ),
          _buildDropdown(
            "Resting ECG",
            ecg,
            const {0: "Normal", 1: "ST-T Wave Abnormality", 2: "LV Hypertrophy"},
            (v) => setState(() => ecg = v!),
          ),
          _buildNumericField("Max Heart Rate Achieved (bpm)", thalach, 60, 220,
              (v) => setState(() => thalach = v)),
          _buildDropdown(
            "Exercise-Induced Angina",
            exang,
            const {0: "No", 1: "Yes"},
            (v) => setState(() => exang = v!),
          ),
          _buildDecimalField("ST Depression (Oldpeak)", oldpeak, 0.0, 10.0,
              (v) => setState(() => oldpeak = v)),
          _buildDropdown(
            "ST Slope",
            slope,
            const {0: "Downsloping", 1: "Flat", 2: "Upsloping"},
            (v) => setState(() => slope = v!),
          ),
          const SizedBox(height: 36),

          AppButton(
            text: "Predict Cardiac Risk",
            isLoading: _isLoading,
            onPressed: _evaluateRisk,
            backgroundColor: Colors.pinkAccent.shade100,
            textColor: Colors.black,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNumericField(
      String label, int current, int min, int max, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: current.toString(),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          final n = int.tryParse(v ?? "");
          if (n == null || n < min || n > max) {
            return "Must be between $min and $max";
          }
          return null;
        },
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) onChanged(n);
        },
      ),
    );
  }

  Widget _buildDecimalField(String label, double current, double min,
      double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: current.toString(),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          final n = double.tryParse(v ?? "");
          if (n == null || n < min || n > max) {
            return "Must be between $min and $max";
          }
          return null;
        },
        onChanged: (v) {
          final n = double.tryParse(v);
          if (n != null) onChanged(n);
        },
      ),
    );
  }

  Widget _buildDropdown(String label, int value, Map<int, String> options,
      ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        dropdownColor: const Color(0xFF1E293B),
        items: options.entries
            .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value,
                    style: const TextStyle(color: Colors.white))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

