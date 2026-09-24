import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/auth/app_role.dart';
import '../../../../data/datasources/notification_template.dart';
import '../../../../services/session_controller.dart';

class NotificationTemplatesScreen extends StatefulWidget {
  const NotificationTemplatesScreen({super.key});
  @override
  State<NotificationTemplatesScreen> createState() =>
      _NotificationTemplatesScreenState();
}

class _NotificationTemplatesScreenState
    extends State<NotificationTemplatesScreen> {
  final _catalog = NotificationTemplateDefinition.load();
  final _templates = FirebaseFirestore.instance
      .collection('notification_templates')
      .snapshots();
  String _locale = 'en';

  @override
  Widget build(BuildContext context) {
    if (context.watch<SessionController>().role != AppRole.platformOwner) {
      return const Scaffold(
        body: Center(child: Text('Product Owner access is required.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('SMS & email templates')),
      body: FutureBuilder<List<NotificationTemplateDefinition>>(
        future: _catalog,
        builder: (context, catalog) {
          if (catalog.hasError) {
            return const Center(
              child: Text('Unable to load the template library.'),
            );
          }
          if (!catalog.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _templates,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Unable to read templates. Check your connection and owner permissions.',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final saved = {
                for (final doc in snapshot.data!.docs) doc.id: doc.data(),
              };
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Message library',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Edit the messages sent by every clinic. Each event has separate SMS and email templates. Saved changes apply to future deliveries.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _locale,
                    decoration: const InputDecoration(
                      labelText: 'Message language',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
                      DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
                    ],
                    onChanged: (value) => setState(() => _locale = value!),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hindi and Gujarati use the saved English message until you save a translation. Provider template IDs must match the language and approved content. Password reset SMS is sent only to a verified account phone.',
                  ),
                  const SizedBox(height: 20),
                  for (final item in catalog.data!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.category,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              Text(
                                item.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  for (final channel in ['sms', 'email'])
                                    OutlinedButton.icon(
                                      icon: Icon(
                                        channel == 'sms'
                                            ? Icons.sms_outlined
                                            : Icons.mail_outline,
                                      ),
                                      label: Text(
                                        '${channel.toUpperCase()} · ${saved['${item.id}_${channel}_$_locale']?['enabled'] == false ? 'Off' : 'Edit'}',
                                      ),
                                      onPressed: () async {
                                        final key =
                                            '${item.id}_${channel}_$_locale';
                                        final english =
                                            saved['${item.id}_${channel}_en'];
                                        await showDialog<void>(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (_) => _TemplateEditor(
                                            definition: item,
                                            channel: channel,
                                            locale: _locale,
                                            original: saved[key],
                                            initial:
                                                saved[key] ??
                                                english ??
                                                item.defaults(channel, _locale),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({
    required this.definition,
    required this.channel,
    required this.locale,
    required this.original,
    required this.initial,
  });
  final NotificationTemplateDefinition definition;
  final String channel;
  final String locale;
  final Map<String, dynamic>? original;
  final Map<String, dynamic> initial;
  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  final _form = GlobalKey<FormState>();
  late final _subject = TextEditingController(
    text: widget.initial['subject'] as String? ?? '',
  );
  late final _body = TextEditingController(
    text: widget.initial['body'] as String? ?? '',
  );
  late final _msg91 = TextEditingController(
    text: widget.initial['msg91_template_id'] as String? ?? '',
  );
  late final _twilio = TextEditingController(
    text: widget.initial['twilio_template_id'] as String? ?? '',
  );
  late bool _enabled = widget.initial['enabled'] != false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_subject, _body, _msg91, _twilio]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final ref = db
          .collection('notification_templates')
          .doc('${widget.definition.id}_${widget.channel}_${widget.locale}');
      await db.runTransaction((transaction) async {
        final latest = await transaction.get(ref);
        if (latest.exists != (widget.original != null) ||
            latest.data()?['revision'] != widget.original?['revision']) {
          throw StateError(
            'Another owner updated this template. Close and reopen it to load their changes.',
          );
        }
        final revision =
            ((latest.data()?['revision'] as num?)?.toInt() ?? 0) + 1;
        final data = {
          'event': widget.definition.id,
          'channel': widget.channel,
          'locale': widget.locale,
          'enabled': _enabled,
          'subject': widget.channel == 'email' ? _subject.text.trim() : '',
          'body': _body.text.trim(),
          'msg91_template_id': _msg91.text.trim(),
          'twilio_template_id': _twilio.text.trim(),
          'revision': revision,
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': FirebaseAuth.instance.currentUser!.uid,
        };
        transaction.set(ref, data);
        transaction.set(ref.collection('history').doc('$revision'), data);
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Could not save. Check your connection and owner access, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(
        '${widget.definition.label} · ${widget.channel.toUpperCase()} · ${widget.locale.toUpperCase()}',
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Send this notification'),
                  value: _enabled,
                  onChanged:
                      _saving ||
                          (widget.definition.id == 'password_reset' &&
                              widget.channel == 'email')
                      ? null
                      : (value) => setState(() => _enabled = value),
                ),
                if (widget.channel == 'email') ...[
                  TextFormField(
                    controller: _subject,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Email subject',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) =>
                        RegExp(r'[\r\n]').hasMatch(value ?? '')
                        ? 'Use a single-line subject.'
                        : widget.definition.validateContent(value ?? ''),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _body,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: widget.channel == 'sms' ? 1600 : 10000,
                  decoration: const InputDecoration(labelText: 'Message'),
                  onChanged: (_) => setState(() {}),
                  validator: (value) => widget.definition.validateContent(
                    value ?? '',
                    body: true,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Insert a placeholder. Names and details are filled automatically.',
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final variable in widget.definition.variables)
                      ActionChip(
                        label: Text('{{$variable}}'),
                        onPressed: () {
                          final selection = _body.selection;
                          final start = selection.isValid
                              ? selection.start
                              : _body.text.length;
                          final end = selection.isValid ? selection.end : start;
                          final token = '{{$variable}}';
                          _body.value = TextEditingValue(
                            text: _body.text.replaceRange(start, end, token),
                            selection: TextSelection.collapsed(
                              offset: start + token.length,
                            ),
                          );
                          setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Preview · sample details',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (widget.channel == 'email')
                  Text(
                    templatePreview(_subject.text),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                SelectableText(templatePreview(_body.text)),
                const SizedBox(height: 20),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Provider template mapping'),
                  children: [
                    const Text(
                      'MSG91 requires an approved provider template using the message and subject variables. Twilio SMS uses variables 1=name, 2=clinic, 3=message. A blank SendGrid ID sends the edited email directly; a custom SendGrid template must use subject and message variables. SMS charges may increase for long or Unicode messages.',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _msg91,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'MSG91 template ID (blank = global default)',
                      ),
                    ),
                    TextFormField(
                      controller: _twilio,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: widget.channel == 'email'
                            ? 'SendGrid template ID (optional)'
                            : 'Twilio Content SID (optional)',
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  final defaults = widget.definition.defaults(
                    widget.channel,
                    widget.locale,
                  );
                  setState(() {
                    _body.text = defaults['body'] as String;
                    _subject.text = defaults['subject'] as String;
                  });
                },
          child: const Text('Load default text'),
        ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save template'),
        ),
      ],
    ),
  );
}
