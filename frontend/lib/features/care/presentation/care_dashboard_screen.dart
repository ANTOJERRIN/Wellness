import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/presentation/dashboard_screen.dart';
import '../../profile/presentation/health_profile_screen.dart';
import '../../specialist/presentation/specialist_screen.dart';
import '../data/care_api.dart';
import 'consultation_screen.dart';

Map<String, dynamic> reviewDashboard(String role) => {
  'role': role,
  'name': role == 'doctor' ? 'Dr. Alex (sample)' : 'Sam (sample)',
  'activeConsultations': 1,
  'chatSessions': 2,
  'profileFieldsCompleted': 3,
  'ai': {'configured': false},
  'consultations': [
    {
      'id': 'sample',
      'patientName': 'Sam (sample)',
      'doctorName': 'Dr. Alex (sample)',
      'reason': 'I would like to discuss my general wellness routine.',
      'status': 'requested',
    },
  ],
};

class CareDashboardScreen extends ConsumerStatefulWidget {
  final String? previewRole;
  const CareDashboardScreen({super.key, this.previewRole});
  @override
  ConsumerState<CareDashboardScreen> createState() => _CareDashboardState();
}

class _CareDashboardState extends ConsumerState<CareDashboardScreen> {
  String? _aiResult;
  bool _checkingAi = false;
  bool get preview => widget.previewRole != null;

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _checkAi() async {
    setState(() => _checkingAi = true);
    try {
      final result = await ref.read(careApiProvider).checkAi();
      const reasons = {
        'not_configured':
            'AI is not configured. Contact the app operator to enable it.',
        'authentication_failed': 'The AI connection credentials were rejected.',
        'access_denied': 'The AI provider denied access to this account.',
        'model_unavailable': 'The configured AI model is unavailable.',
        'rate_limited':
            'The AI provider has reached its usage limit. Please try later.',
        'timeout':
            'The AI provider took too long to respond. Please try again.',
      };
      if (mounted) {
        setState(
          () => _aiResult = result['connected'] == true
              ? 'AI connection verified.'
              : reasons[result['reason']] ??
                    'AI is temporarily unavailable. Your care team is still accessible.',
        );
      }
    } catch (error) {
      if (mounted) _notice(careError(error));
    } finally {
      if (mounted) setState(() => _checkingAi = false);
    }
  }

  Future<void> _request() async {
    if (preview) {
      _open(const AuthScreen());
      return;
    }
    try {
      final doctors = await ref.read(careApiProvider).doctors();
      if (!mounted) return;
      if (doctors.isEmpty) {
        _notice(
          'No approved doctors are available yet. You can use Find a specialist to explore care options.',
        );
        return;
      }
      final result = await showDialog<({int doctorId, String reason})>(
        context: context,
        builder: (_) => _RequestDialog(doctors: doctors),
      );
      if (result == null || !mounted) return;
      await ref.read(careApiProvider).request(result.doctorId, result.reason);
      if (!mounted) return;
      ref.invalidate(careDashboardProvider);
      _notice('Consultation request sent. Your doctor can now reply here.');
    } catch (error) {
      if (mounted) _notice(careError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!preview && !ref.watch(authProvider).isAuthenticated) {
      return const AuthScreen();
    }
    if (preview) return _page(reviewDashboard(widget.previewRole!));
    return ref
        .watch(careDashboardProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Your dashboard')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(careError(error)),
                  TextButton(
                    onPressed: () => ref.invalidate(careDashboardProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: _page,
        );
  }

  Widget _page(Map<String, dynamic> data) {
    final role = data['role'];
    final doctor = role == 'doctor' || role == 'doctor_pending';
    final pending = role == 'doctor_pending';
    final rows = (data['consultations'] as List).cast<Map<String, dynamic>>();
    final aiConfigured = (data['ai'] as Map)['configured'] == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(doctor ? 'Doctor dashboard' : 'Patient dashboard'),
        actions: [
          if (!preview)
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: () => ref.invalidate(careDashboardProvider),
              icon: const Icon(Icons.refresh),
            ),
          if (preview)
            TextButton(
              onPressed: () => _open(const AuthScreen()),
              child: const Text('Sign in'),
            ),
          if (!preview)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!preview) {
            ref.invalidate(careDashboardProvider);
            await ref.read(careDashboardProvider.future);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preview)
                      Card(
                        color: Colors.amber.withValues(alpha: .12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Review preview · Sample data',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Explore the patient and doctor views. Sign in to use your own records and send requests.',
                              ),
                              Wrap(
                                spacing: 12,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/review/patient',
                                        ),
                                    child: const Text('Patient view'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pushReplacementNamed(
                                          context,
                                          '/review/doctor',
                                        ),
                                    child: const Text('Doctor view'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome, ${data['name']}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      doctor
                          ? 'Manage consultation requests and follow up with your patients.'
                          : 'Your care, conversations and health profile in one place.',
                    ),
                    const SizedBox(height: 24),
                    if (pending)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Doctor approval pending. An operator must approve your account before you can receive or respond to patient requests.',
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _stat(
                          'Active consultations',
                          '${data['activeConsultations']}',
                          Icons.forum_outlined,
                        ),
                        _stat(
                          doctor ? 'New requests' : 'Health profile',
                          doctor
                              ? '${rows.where((r) => r['status'] == 'requested').length}'
                              : '${data['profileFieldsCompleted']}/5 fields',
                          doctor
                              ? Icons.inbox_outlined
                              : Icons.assignment_ind_outlined,
                        ),
                        _stat(
                          doctor
                              ? 'Completed consultations'
                              : 'AI conversations',
                          doctor
                              ? '${rows.where((r) => r['status'] == 'closed').length}'
                              : '${data['chatSessions']}',
                          Icons.chat_bubble_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI assistant',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _aiResult ??
                                  (preview
                                      ? 'Sample preview. No live AI connection is claimed.'
                                      : aiConfigured
                                      ? 'Provider configured. Check the connection before starting a conversation.'
                                      : 'AI is currently unavailable because the provider has not been configured. You can still contact your care team.'),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => _open(
                                    preview
                                        ? const AuthScreen()
                                        : const DashboardScreen(),
                                  ),
                                  icon: const Icon(Icons.chat_outlined),
                                  label: Text(
                                    preview
                                        ? 'Sign in to chat'
                                        : 'Open assistant',
                                  ),
                                ),
                                if (!preview)
                                  OutlinedButton(
                                    onPressed: _checkingAi ? null : _checkAi,
                                    child: Text(
                                      _checkingAi
                                          ? 'Checking…'
                                          : 'Check AI connection',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (!doctor)
                          FilledButton.icon(
                            onPressed: _request,
                            icon: const Icon(Icons.add),
                            label: const Text('Request consultation'),
                          ),
                        if (!doctor)
                          OutlinedButton.icon(
                            onPressed: () => _open(
                              preview
                                  ? const AuthScreen()
                                  : const HealthProfileScreen(),
                            ),
                            icon: const Icon(Icons.person_outline),
                            label: const Text('Health profile'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _open(const SpecialistScreen()),
                          icon: const Icon(Icons.local_hospital_outlined),
                          label: const Text('Find a specialist'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      doctor ? 'Patient consultations' : 'Your consultations',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Messages are asynchronous. For urgent symptoms, contact local emergency services.',
                    ),
                    const SizedBox(height: 12),
                    if (rows.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            doctor
                                ? 'No patient requests yet. Assigned consultations will appear here.'
                                : 'No consultations yet. Choose a doctor to start a conversation.',
                          ),
                        ),
                      ),
                    for (final row in rows)
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const CircleAvatar(
                            child: Icon(Icons.medical_services_outlined),
                          ),
                          title: Text(
                            doctor
                                ? row['patientName'] as String
                                : row['doctorName'] as String,
                          ),
                          subtitle: Text(
                            '${row['reason']}\n${(row['status'] as String).replaceAll('_', ' ')}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConsultationScreen(
                                  consultation: row,
                                  doctor: doctor,
                                  preview: preview,
                                ),
                              ),
                            );
                            if (mounted && !preview) {
                              ref.invalidate(careDashboardProvider);
                            }
                          },
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

  Widget _stat(String title, String value, IconData icon) => SizedBox(
    width: 300,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF10B981)),
            const SizedBox(height: 16),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(title),
          ],
        ),
      ),
    ),
  );
}

class _RequestDialog extends StatefulWidget {
  final List<Map<String, dynamic>> doctors;
  const _RequestDialog({required this.doctors});
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  int? _doctorId;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request a consultation'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Choose a doctor'),
                items: widget.doctors
                    .map(
                      (row) => DropdownMenuItem(
                        value: row['id'] as int,
                        child: Text(row['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _doctorId = value,
                validator: (value) =>
                    value == null ? 'Please choose a doctor' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reason,
                maxLength: 2000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'How can the doctor help?',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Please enter at least 10 characters'
                    : null,
              ),
              const Text(
                'Only this request and messages you send are shared with the selected doctor. This is not an emergency service.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              doctorId: _doctorId!,
              reason: _reason.text.trim(),
            ));
          }
        },
        child: const Text('Send request'),
      ),
    ],
  );
}
