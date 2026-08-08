import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/friendly_error.dart';
import '../../providers.dart';
import 'agenda_review_screen.dart';

/// Agenda ingestion via iCal: paste raw `.ics` text or supply a URL.
///
/// Hits `POST /api/agenda/ical` and routes the parsed drafts to
/// [AgendaReviewScreen] for user confirmation.
class ICalImportScreen extends ConsumerStatefulWidget {
  const ICalImportScreen({super.key});

  @override
  ConsumerState<ICalImportScreen> createState() => _ICalImportScreenState();
}

class _ICalImportScreenState extends ConsumerState<ICalImportScreen> {
  final _urlCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final url = _urlCtrl.text.trim();
      final text = _textCtrl.text.trim();
      final drafts = url.isNotEmpty
          ? await api.importIcalUrl(url)
          : text.isNotEmpty
              ? await api.importIcalText(text)
              : throw StateError('Provide either a URL or paste an .ics payload');
      if (!mounted) return;
      if (drafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("We couldn't find any upcoming events in that feed.")),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AgendaReviewScreen(drafts: drafts)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${friendlyApiError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import calendar (iCal)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Calendar URL (optional)',
              hintText: 'https://school.example/calendar.ics',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl,
            decoration: const InputDecoration(
              labelText: 'Or paste .ics text',
              hintText: 'BEGIN:VCALENDAR\n…\nEND:VCALENDAR',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 12,
            minLines: 6,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_busy ? 'Importing…' : 'Import'),
          ),
        ],
      ),
    );
  }
}
