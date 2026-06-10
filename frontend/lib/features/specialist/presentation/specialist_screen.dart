import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class SpecialistScreen extends ConsumerStatefulWidget {
  const SpecialistScreen({super.key});

  @override
  ConsumerState<SpecialistScreen> createState() => _SpecialistScreenState();
}

class _SpecialistScreenState extends ConsumerState<SpecialistScreen>
    with SingleTickerProviderStateMixin {
  final _symptomsCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _gender = "male";
  String _severity = "moderate";
  String _duration = "";

  bool _isLoading = false;
  List<Map<String, dynamic>>? _results;
  List<String> _disclaimers = [];

  // Hospital search
  final _stateCtrl = TextEditingController();
  bool _hospitalsLoading = false;
  List<Map<String, dynamic>>? _hospitals;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _symptomsCtrl.dispose();
    _ageCtrl.dispose();
    _stateCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _results = null;
    });
    try {
      final res = await ref.read(dioProvider).post("/specialist/recommend",
          data: {
            "symptoms": _symptomsCtrl.text.trim(),
            "age": _ageCtrl.text.trim(),
            "gender": _gender,
            "severity": _severity,
            "duration": _duration,
          });
      setState(() {
        _results = List<Map<String, dynamic>>.from(
            res.data["recommendations"] ?? []);
        _disclaimers =
            List<String>.from(res.data["disclaimers"] ?? []);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Failed to get recommendations. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _findHospitals() async {
    if (_stateCtrl.text.trim().isEmpty) return;
    setState(() {
      _hospitalsLoading = true;
      _hospitals = null;
    });
    try {
      final res = await ref.read(dioProvider).get(
          "/hospitals/nearby",
          queryParameters: {"state": _stateCtrl.text.trim()});
      setState(() {
        _hospitals =
            List<Map<String, dynamic>>.from(res.data["hospitals"] ?? []);
        _hospitalsLoading = false;
      });
    } catch (_) {
      setState(() => _hospitalsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Find a Specialist"),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.person_search), text: "Recommend"),
            Tab(icon: Icon(Icons.local_hospital), text: "Hospitals"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildRecommendTab(),
          _buildHospitalsTab(),
        ],
      ),
    );
  }

  Widget _buildRecommendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Input form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Describe Your Symptoms",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _symptomsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Symptoms *",
                        hintText:
                            "e.g., chest pain, shortness of breath, headache...",
                        prefixIcon: Icon(Icons.sick_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? "Please describe your symptoms"
                          : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Age",
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _gender,
                            dropdownColor: const Color(0xFF1E293B),
                            decoration: const InputDecoration(
                              labelText: "Gender",
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: "male",
                                  child: Text("Male",
                                      style:
                                          TextStyle(color: Colors.white))),
                              DropdownMenuItem(
                                  value: "female",
                                  child: Text("Female",
                                      style:
                                          TextStyle(color: Colors.white))),
                            ],
                            onChanged: (v) =>
                                setState(() => _gender = v ?? "male"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _severity,
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: const InputDecoration(
                        labelText: "Severity",
                        prefixIcon: Icon(Icons.trending_up),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: "mild",
                            child: Text("Mild",
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: "moderate",
                            child: Text("Moderate",
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: "severe",
                            child: Text("Severe",
                                style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: "extreme",
                            child: Text("Extreme — Emergency",
                                style: TextStyle(color: Colors.redAccent))),
                      ],
                      onChanged: (v) =>
                          setState(() => _severity = v ?? "moderate"),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: "Duration (optional)",
                        hintText: "e.g., 3 days, 2 weeks",
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      onChanged: (v) => _duration = v,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _getRecommendations,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black))
                            : const Icon(Icons.search),
                        label: const Text("Get Recommendations",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Results
          if (_results != null) ...[
            ..._results!.map((rec) => _buildRecommendationCard(rec)),
            const SizedBox(height: 16),
            // Disclaimers
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text("Disclaimer",
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._disclaimers.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "• $d",
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 11.5, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    final urgency = rec["urgency"] ?? "medium";
    final urgencyColor = urgency == "high"
        ? Colors.redAccent
        : urgency == "medium"
            ? Colors.orange
            : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services,
                  color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rec["specialty"] ?? "Specialist",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: urgencyColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  urgency.toUpperCase(),
                  style: TextStyle(
                      color: urgencyColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(rec["description"] ?? "",
              style:
                  const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Text(rec["reason"] ?? "",
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.4)),
          if ((rec["additionalInfo"] ?? "").isNotEmpty) ...[
            const SizedBox(height: 8),
            Text("ℹ️ ${rec["additionalInfo"]}",
                style: const TextStyle(
                    color: Color(0xFF93C5FD), fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildHospitalsTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Find Nearby Hospitals",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Search by state to find hospitals with emergency facilities.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stateCtrl,
                          decoration: const InputDecoration(
                            labelText: "State (e.g., Karnataka)",
                            prefixIcon:
                                Icon(Icons.location_on_outlined),
                          ),
                          textCapitalization:
                              TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed:
                            _hospitalsLoading ? null : _findHospitals,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                        child: _hospitalsLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black))
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_hospitals != null)
            Expanded(
              child: _hospitals!.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_hospital_outlined,
                              color: Colors.grey, size: 48),
                          SizedBox(height: 12),
                          Text("No hospitals found for this state.",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _hospitals!.length,
                      itemBuilder: (context, i) {
                        final h = _hospitals![i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_hospital,
                                      color: Colors.redAccent,
                                      size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      h["name"] ?? "Hospital",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if ((h["contact"] ?? "N/A") != "N/A")
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined,
                                        color: Color(0xFF10B981),
                                        size: 14),
                                    const SizedBox(width: 6),
                                    Text(h["contact"],
                                        style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 13)),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.grey, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      h["address"] ?? "",
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
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
}

