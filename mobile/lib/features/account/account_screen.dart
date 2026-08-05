import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../providers.dart';
import '../auth/auth_controller.dart';

/// Account, trial/subscription status, and plan selection.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final profile = await api.me();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Offline or unauthenticated — show local placeholder.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = _profile?['subscription'] as Map<String, dynamic>?;
    final user = _profile?['user'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user?['email'] as String? ?? 'You'),
            subtitle: Text(
                subscription == null ? 'No active plan' : 'Signed in'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subscription',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_loading)
                  const LinearProgressIndicator()
                else if (subscription == null)
                  const Text(
                    'Your trial or plan has ended. Your synced notes stay '
                    'available offline, but new AI processing is paused.',
                  )
                else ...[
                  _PlanRow(
                    label: 'Plan',
                    value: _prettyPlan(subscription['plan'] as String?),
                  ),
                  _PlanRow(
                    label: 'Status',
                    value: subscription['status'] as String? ?? '—',
                  ),
                  _PlanRow(
                    label: 'Expires',
                    value: _formatDate(subscription['expires_at'] as String?),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plans', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                _PlanChoice(
                  title: 'Monthly',
                  subtitle: '\$5 / month — cancel anytime',
                ),
                SizedBox(height: 8),
                _PlanChoice(
                  title: 'Annual',
                  subtitle: '\$50 / year — ~2 months free',
                  highlighted: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () =>
              ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }

  String _prettyPlan(String? plan) => switch (plan) {
        'trial' => 'Free trial',
        'monthly' => 'Monthly',
        'annual' => 'Annual',
        _ => plan ?? '—',
      };

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label,
              style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PlanChoice extends StatelessWidget {
  const _PlanChoice({
    required this.title,
    required this.subtitle,
    this.highlighted = false,
  });
  final String title;
  final String subtitle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: highlighted ? Colors.indigo : Colors.grey.shade300),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: highlighted
          ? const Chip(label: Text('Best value'))
          : null,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billing integration (App Store / Play / Stripe) '
                'is a tracked open decision.'),
          ),
        );
      },
    );
  }
}
