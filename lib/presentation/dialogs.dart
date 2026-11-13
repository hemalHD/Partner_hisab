import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/format.dart';
import '../domain/ledger.dart';
import '../domain/ledger_service.dart';
import '../domain/models.dart';
import 'cubits.dart';
import 'theme.dart';
import 'widgets.dart';

// ---------------------------------------------------------------- building blocks

/// Shared save behaviour: run the action, close on success, show the rule that
/// was broken on failure.
mixin SaveMixin<T extends StatefulWidget> on State<T> {
  String? error;
  bool busy = false;

  Future<void> run(Future<void> Function() action, String doneMessage,
      {VoidCallback? after}) async {
    if (busy) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
      after?.call();
    } on LedgerError catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Could not save: $e';
          busy = false;
        });
      }
    }
  }
}

class DialogFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? error;
  final String cta;
  final VoidCallback? onSave;

  const DialogFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.cta,
    required this.onSave,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 13, color: c.mut)),
              for (final child in children) ...[
                const SizedBox(height: 16),
                child,
              ],
              if (error != null) ...[
                const SizedBox(height: 14),
                Text(error!,
                    style: TextStyle(
                        fontSize: 13,
                        color: c.negInk,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel')),
                  FilledButton(onPressed: onSave, child: Text(cta)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two fields side by side, stacked when the dialog is narrow.
class FieldRow extends StatelessWidget {
  final List<Widget> children;
  const FieldRow(this.children, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 420) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      );
    });
  }
}

class DateField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const DateField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(isoDate(picked));
      },
      borderRadius: BorderRadius.circular(8),
      child: LabeledField(
        label: label,
        child: InputDecorator(
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            suffixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 20),
          ),
          child: Text(value.isEmpty ? 'Choose' : formatDate(value),
              style: const TextStyle(fontSize: 15)),
        ),
      ),
    );
  }
}

class Choice<T> {
  final T value;
  final String label;
  const Choice(this.value, this.label);
}

class ChoiceField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<Choice<T>> options;
  final ValueChanged<T?> onChanged;
  const ChoiceField(
      {super.key,
      required this.label,
      required this.value,
      required this.options,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final valid = options.any((o) => o.value == value);
    return LabeledField(
      label: label,
      child: InputDecorator(
        decoration: const InputDecoration(
            contentPadding: EdgeInsets.fromLTRB(11, 13, 8, 14)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: valid ? value : null,
            isExpanded: true,
            isDense: true,
            items: [
              for (final o in options)
                DropdownMenuItem<T>(
                  value: o.value,
                  child: Text(o.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            style: TextStyle(fontSize: 15, color: LedgerColors.of(context).fg),
            borderRadius: BorderRadius.circular(8),
            onChanged: options.isEmpty ? null : onChanged,
          ),
        ),
      ),
    );
  }
}

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final bool autofocus;
  final String? hint;
  const AmountField(
      {super.key,
      required this.controller,
      required this.label,
      required this.onChanged,
      this.autofocus = false,
      this.hint});

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      hint: hint,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: const TextStyle(fontSize: 15, fontFeatures: tabularFigures),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(hintText: '0'),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class PreviewBox extends StatelessWidget {
  final List<Widget> children;
  const PreviewBox({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// A preview line: a label on the left and one or more values on the right.
class PreviewLine extends StatelessWidget {
  final Widget label;
  final List<Widget> values;
  final bool header;
  const PreviewLine(this.label, this.values, {super.key, this.header = false});

  @override
  Widget build(BuildContext context) {
    final style = header
        ? TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant)
        : const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DefaultTextStyle.merge(
        style: style,
        child: Row(
          children: [
            Expanded(flex: 5, child: label),
            for (final v in values)
              Expanded(
                  flex: 3,
                  child: Align(alignment: Alignment.centerRight, child: v)),
          ],
        ),
      ),
    );
  }
}

class WarnBox extends StatelessWidget {
  final String text;
  const WarnBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = LedgerColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.negSoft,
        border: Border.all(color: c.neg),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 13, color: c.negInk, fontWeight: FontWeight.w600)),
    );
  }
}

List<Choice<int>> _siteChoices(Ledger l) =>
    [for (final s in l.data.sites) Choice(s.id, s.name)];

Ledger _ledgerOf(BuildContext context) =>
    context.watch<LedgerCubit>().state.ledger!;

// ---------------------------------------------------------------- add money

class AddMoneyDialog extends StatefulWidget {
  final int? siteId;
  final int? partnerId;
  const AddMoneyDialog({super.key, this.siteId, this.partnerId});

  @override
  State<AddMoneyDialog> createState() => _AddMoneyDialogState();
}

class _AddMoneyDialogState extends State<AddMoneyDialog> with SaveMixin {
  int? _site;
  int? _partner;
  String _date = todayIso();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final l = context.read<LedgerCubit>().state.ledger!;
    _partner = widget.partnerId;
    _site = widget.siteId;
    final pid = _partner;
    if (_site == null && pid != null) {
      // Open on the site where this partner owes the most.
      int? lowest;
      for (final s in l.activeSitesOf(pid)) {
        final b = l.balanceOf(s.id, pid).balance;
        if (lowest == null || b < lowest) {
          lowest = b;
          _site = s.id;
        }
      }
    }
    _site ??= l.data.sites.isEmpty ? null : l.data.sites.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _ledgerOf(context);
    final site = _site;
    final lines = site == null
        ? const <ShareLine>[]
        : (l.versionAt(site, _date) ?? l.currentVersion(site))?.lines ??
            const <ShareLine>[];
    final partners = [
      for (final x in lines) Choice(x.partnerId, l.partnerName(x.partnerId))
    ];
    final int? partner = partners.any((c) => c.value == _partner)
        ? _partner
        : (partners.isEmpty ? null : partners.first.value);
    final balance = (site == null || partner == null)
        ? 0
        : l.balanceOf(site, partner).balance;
    final amount = parseMoney(_amount.text);

    return DialogFrame(
      title: 'Add money',
      subtitle: "Raises only the chosen partner's balance on the chosen site.",
      cta: 'Save',
      error: error,
      onSave: (site == null || partner == null)
          ? null
          : () => run(
                () => context.read<LedgerCubit>().addMoney(
                      siteId: site,
                      partnerId: partner,
                      date: _date,
                      amount: amount,
                      note: _note.text,
                    ),
                'Money added',
              ),
      children: [
        FieldRow([
          ChoiceField<int>(
            label: 'Site',
            value: site,
            options: _siteChoices(l),
            onChanged: (v) => setState(() => _site = v),
          ),
          ChoiceField<int>(
            label: 'Partner',
            value: partner,
            options: partners,
            onChanged: (v) => setState(() => _partner = v),
          ),
        ]),
        FieldRow([
          AmountField(
            controller: _amount,
            label: 'Amount (₹)',
            autofocus: true,
            onChanged: () => setState(() {}),
          ),
          DateField(
            label: 'Date',
            value: _date,
            onChanged: (v) => setState(() => _date = v),
          ),
        ]),
        if (balance < 0)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _amount.text = formatNumber(-balance);
              }),
              child: Text('Clear negative · ${formatMoney(-balance)}'),
            ),
          ),
        LabeledField(
            label: 'Note (optional)',
            child: TextField(
              controller: _note,
              decoration: const InputDecoration(
                  hintText: 'Cash, cheque no., bank transfer'),
            )),
        if (partner == null)
          const WarnBox('This site has no partners yet. Set shares first.')
        else
          PreviewBox(children: [
            PreviewLine(const Text('Current balance'), [MoneyText(balance)]),
            PreviewLine(const Text('Adding'), [MoneyText(amount)]),
            const Divider(),
            PreviewLine(
              Row(children: [
                const Text('Balance after',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                StatusChip(balance + amount),
              ]),
              [MoneyText(balance + amount)],
            ),
          ]),
      ],
    );
  }
}

// ---------------------------------------------------------------- new entry

class NewEntryDialog extends StatefulWidget {
  final int? siteId;
  final PlannedEntry? planned;
  const NewEntryDialog({super.key, this.siteId, this.planned});

  @override
  State<NewEntryDialog> createState() => _NewEntryDialogState();
}

class _NewEntryDialogState extends State<NewEntryDialog> with SaveMixin {
  int? _site;
  String _date = todayIso();
  final _income = TextEditingController();
  final _expense = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final l = context.read<LedgerCubit>().state.ledger!;
    final p = widget.planned;
    _site = p?.siteId ??
        widget.siteId ??
        (l.data.sites.isEmpty ? null : l.data.sites.first.id);
    if (p != null) {
      (p.isIncome ? _income : _expense).text = formatNumber(p.amount);
      _note.text = p.note;
    }
  }

  @override
  void dispose() {
    _income.dispose();
    _expense.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _ledgerOf(context);
    final site = _site;
    final income = parseMoney(_income.text);
    final expense = parseMoney(_expense.text);
    final version = site == null ? null : l.versionAt(site, _date);

    Widget preview;
    if (site == null) {
      preview = const WarnBox('Add a site first.');
    } else if (version == null) {
      preview = const WarnBox(
          'This site has no shares in force on that date. Set shares or pick a later date.');
    } else {
      final parts = allocateIncomeExpense(income, expense, version.lines);
      preview = PreviewBox(children: [
        PreviewLine(
          const Text('Net of this entry',
              style: TextStyle(fontWeight: FontWeight.w600)),
          [MoneyText(income - expense)],
        ),
        const Divider(),
        const PreviewLine(
          Text('Partner'),
          [Text('Share'), Text('This entry'), Text('Balance after')],
          header: true,
        ),
        for (var i = 0; i < version.lines.length; i++)
          PreviewLine(
            Text(l.partnerName(version.lines[i].partnerId),
                overflow: TextOverflow.ellipsis),
            [
              Text(formatPercent(version.lines[i].bp)),
              MoneyText(parts[i].amount),
              MoneyText(l.balanceOf(site, version.lines[i].partnerId).balance +
                  parts[i].amount),
            ],
          ),
      ]);
    }

    return DialogFrame(
      title: 'New entry',
      subtitle:
          'Fill income, expense or both. The amount is split across partners by their share on that date.',
      cta: 'Save entry',
      error: error,
      onSave: site == null
          ? null
          : () => run(
                () => context.read<LedgerCubit>().addIncomeExpense(
                      siteId: site,
                      date: _date,
                      income: income,
                      expense: expense,
                      note: _note.text,
                      plannedId: widget.planned?.id,
                    ),
                'Entry saved',
              ),
      children: [
        FieldRow([
          ChoiceField<int>(
            label: 'Site',
            value: site,
            options: _siteChoices(l),
            onChanged: (v) => setState(() => _site = v),
          ),
          DateField(
            label: 'Date',
            value: _date,
            onChanged: (v) => setState(() => _date = v),
          ),
        ]),
        FieldRow([
          AmountField(
            controller: _income,
            label: 'Income (₹)',
            autofocus: true,
            onChanged: () => setState(() {}),
          ),
          AmountField(
            controller: _expense,
            label: 'Expense (₹)',
            onChanged: () => setState(() {}),
          ),
        ]),
        LabeledField(
            label: 'Details (optional)',
            child: TextField(
              controller: _note,
              decoration:
                  const InputDecoration(hintText: 'What is this entry for?'),
            )),
        preview,
      ],
    );
  }
}

// ---------------------------------------------------------------- transfer

class TransferDialog extends StatefulWidget {
  final int? partnerId;
  final int? siteId;
  const TransferDialog({super.key, this.partnerId, this.siteId});

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> with SaveMixin {
  int? _partner;
  int? _from;
  int? _to;
  String _date = todayIso();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    final l = context.read<LedgerCubit>().state.ledger!;
    _partner = widget.partnerId;
    _from = widget.siteId;
    final from = _from;
    if (_partner == null && from != null) {
      // Suggest the partner with the most money on this site who is also on
      // another site.
      int? best;
      for (final x in l.currentVersion(from)?.lines ?? const <ShareLine>[]) {
        if (l.sitesEverOn(x.partnerId).length < 2) continue;
        final b = l.balanceOf(from, x.partnerId).balance;
        if (best == null || b > best) {
          best = b;
          _partner = x.partnerId;
        }
      }
    }
    _partner ??= l.data.partners.isEmpty ? null : l.data.partners.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// The chosen source site, or the one where the partner has the most money.
  int? _resolveFrom(Ledger l, int? partner, List<Site> sites) {
    if (sites.any((s) => s.id == _from)) return _from;
    if (partner == null) return null;
    int? best;
    int? pick;
    for (final s in sites) {
      final b = l.balanceOf(s.id, partner).balance;
      if (best == null || b > best) {
        best = b;
        pick = s.id;
      }
    }
    return pick;
  }

  @override
  Widget build(BuildContext context) {
    final l = _ledgerOf(context);
    final partner = _partner;
    final sites = partner == null ? const <Site>[] : l.sitesEverOn(partner);
    final siteOptions = [for (final s in sites) Choice(s.id, s.name)];

    final int? from = _resolveFrom(l, partner, sites);
    final toOptions = [
      for (final c in siteOptions)
        if (c.value != from) c
    ];
    final int? to = toOptions.any((c) => c.value == _to)
        ? _to
        : (toOptions.isEmpty ? null : toOptions.first.value);
    final amount = parseMoney(_amount.text);

    Widget preview;
    if (partner == null || from == null || to == null) {
      preview = const WarnBox(
          'This partner is on only one site, so there is nowhere to transfer to.');
    } else {
      final a = l.balanceOf(from, partner).balance;
      final b = l.balanceOf(to, partner).balance;
      preview = PreviewBox(children: [
        PreviewLine(Text('${l.partnerName(partner)} on'),
            const [Text('Before'), Text('After')],
            header: true),
        PreviewLine(Text(l.siteName(from), overflow: TextOverflow.ellipsis),
            [MoneyText(a), MoneyText(a - amount)]),
        PreviewLine(Text(l.siteName(to), overflow: TextOverflow.ellipsis),
            [MoneyText(b), MoneyText(b + amount)]),
        if (amount > 0 && a - amount < 0) ...[
          const SizedBox(height: 8),
          WarnBox(
              'This leaves the partner in negative on ${l.siteName(from)}. You can still save.'),
        ],
      ]);
    }

    return DialogFrame(
      title: 'Transfer between sites',
      subtitle:
          "Moves one partner's money from one site to another. Their total across sites stays the same.",
      cta: 'Save transfer',
      error: error,
      onSave: (partner == null || from == null || to == null)
          ? null
          : () => run(
                () => context.read<LedgerCubit>().transfer(
                      partnerId: partner,
                      fromSiteId: from,
                      toSiteId: to,
                      date: _date,
                      amount: amount,
                      note: _note.text,
                    ),
                'Transfer saved',
              ),
      children: [
        FieldRow([
          ChoiceField<int>(
            label: 'Partner',
            value: partner,
            options: [for (final p in l.data.partners) Choice(p.id, p.name)],
            onChanged: (v) => setState(() {
              _partner = v;
              _from = null;
              _to = null;
            }),
          ),
          DateField(
            label: 'Date',
            value: _date,
            onChanged: (v) => setState(() => _date = v),
          ),
        ]),
        FieldRow([
          ChoiceField<int>(
            label: 'From site',
            value: from,
            options: siteOptions,
            onChanged: (v) => setState(() => _from = v),
          ),
          ChoiceField<int>(
            label: 'To site',
            value: to,
            options: toOptions,
            onChanged: (v) => setState(() => _to = v),
          ),
        ]),
        FieldRow([
          AmountField(
            controller: _amount,
            label: 'Amount (₹)',
            autofocus: true,
            onChanged: () => setState(() {}),
          ),
          LabeledField(
              label: 'Note (optional)',
              child: TextField(
                controller: _note,
                decoration:
                    const InputDecoration(hintText: 'Reason for the transfer'),
              )),
        ]),
        preview,
      ],
    );
  }
}

// ---------------------------------------------------------------- replace partner

class ReplacePartnerDialog extends StatefulWidget {
  final int siteId;
  const ReplacePartnerDialog({super.key, required this.siteId});

  @override
  State<ReplacePartnerDialog> createState() => _ReplacePartnerDialogState();
}

class _ReplacePartnerDialogState extends State<ReplacePartnerDialog>
    with SaveMixin {
  int? _leaving;
  int? _incoming;
  String _date = todayIso();

  @override
  Widget build(BuildContext context) {
    final l = _ledgerOf(context);
    final siteId = widget.siteId;
    final lines = l.currentVersion(siteId)?.lines ?? const <ShareLine>[];
    final leavingOptions = [
      for (final x in lines)
        Choice(x.partnerId,
            '${l.partnerName(x.partnerId)} (${formatPercent(x.bp)})')
    ];
    final incomingOptions = [
      for (final p in l.data.partners)
        if (!lines.any((x) => x.partnerId == p.id)) Choice(p.id, p.name)
    ];
    final int? leaving = leavingOptions.any((c) => c.value == _leaving)
        ? _leaving
        : (leavingOptions.isEmpty ? null : leavingOptions.first.value);
    final int? incoming = incomingOptions.any((c) => c.value == _incoming)
        ? _incoming
        : (incomingOptions.isEmpty ? null : incomingOptions.first.value);
    final balance = leaving == null ? 0 : l.balanceOf(siteId, leaving).balance;
    final bp = leaving == null ? 0 : l.shareBp(siteId, leaving);

    return DialogFrame(
      title: 'Replace partner',
      subtitle:
          '${l.siteName(siteId)}. The new partner takes over the same share and the full balance on this site.',
      cta: 'Replace partner',
      error: error,
      onSave: (leaving == null || incoming == null)
          ? null
          : () => run(
                () => context.read<LedgerCubit>().replacePartner(
                      siteId: siteId,
                      leavingId: leaving,
                      newId: incoming,
                      date: _date,
                    ),
                'Partner replaced',
              ),
      children: [
        FieldRow([
          ChoiceField<int>(
            label: 'Leaving partner',
            value: leaving,
            options: leavingOptions,
            onChanged: (v) => setState(() => _leaving = v),
          ),
          ChoiceField<int>(
            label: 'New partner',
            value: incoming,
            options: incomingOptions,
            onChanged: (v) => setState(() => _incoming = v),
          ),
        ]),
        DateField(
          label: 'Effective from',
          value: _date,
          onChanged: (v) => setState(() => _date = v),
        ),
        if (incomingOptions.isEmpty)
          const WarnBox(
              'Every partner is already on this site. Create the new partner first under Partners.')
        else if (leaving != null && incoming != null)
          PreviewBox(children: [
            const PreviewLine(
              Text('On this site'),
              [Text('Share'), Text('Now'), Text('After')],
              header: true,
            ),
            PreviewLine(
              Text('${l.partnerName(leaving)} (leaving)',
                  overflow: TextOverflow.ellipsis),
              [
                Text('${formatPercent(bp)} → 0%'),
                MoneyText(balance),
                const MoneyText(0),
              ],
            ),
            PreviewLine(
              Text('${l.partnerName(incoming)} (new)',
                  overflow: TextOverflow.ellipsis),
              [
                Text('0% → ${formatPercent(bp)}'),
                const MoneyText(0),
                MoneyText(balance),
              ],
            ),
          ]),
        if (incoming != null && balance < 0)
          WarnBox(
              '${l.partnerName(incoming)} will start with a negative balance of ${formatMoney(-balance)} on this site.'),
        Text(
          'Any payment between the two partners happens outside the app and is not recorded.',
          style: TextStyle(fontSize: 12, color: mutedColor(context)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- edit shares

class EditSharesDialog extends StatefulWidget {
  final int siteId;
  const EditSharesDialog({super.key, required this.siteId});

  @override
  State<EditSharesDialog> createState() => _EditSharesDialogState();
}

class _EditSharesDialogState extends State<EditSharesDialog> with SaveMixin {
  final Map<int, TextEditingController> _pct = {};
  final _note = TextEditingController();
  late String _date;

  @override
  void initState() {
    super.initState();
    final l = context.read<LedgerCubit>().state.ledger!;
    final first = l.versionsOf(widget.siteId).isEmpty;
    final start = l.site(widget.siteId)?.startDate ?? '';
    _date = first && start.isNotEmpty ? start : todayIso();
    for (final p in l.data.partners) {
      final bp = l.shareBp(widget.siteId, p.id);
      _pct[p.id] = TextEditingController(
          text: bp == 0 ? '' : formatPercent(bp).replaceAll('%', ''));
    }
  }

  @override
  void dispose() {
    for (final c in _pct.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Map<int, int> _values() =>
      {for (final e in _pct.entries) e.key: parsePercent(e.value.text)};

  @override
  Widget build(BuildContext context) {
    final l = _ledgerOf(context);
    final cs = Theme.of(context).colorScheme;
    final total = _values().values.fold<int>(0, (a, b) => a + b);
    final ok = total == 10000;
    final message = ok
        ? 'Exactly 100%. Ready to save.'
        : total < 10000
            ? '${formatPercent(10000 - total)} still to assign'
            : '${formatPercent(total - 10000)} over 100';

    return DialogFrame(
      title: 'Edit shares',
      subtitle:
          '${l.siteName(widget.siteId)}. Saving starts a new share version. Earlier entries keep their old split.',
      cta: 'Save shares',
      error: error,
      // Save stays off until the total is exactly 100%.
      onSave: !ok
          ? null
          : () => run(
                () => context.read<LedgerCubit>().saveShares(
                      siteId: widget.siteId,
                      date: _date,
                      bpByPartner: _values(),
                      note: _note.text,
                    ),
                'Shares saved',
              ),
      children: [
        DateField(
          label: 'Effective from',
          value: _date,
          onChanged: (v) => setState(() => _date = v),
        ),
        if (l.data.partners.isEmpty)
          const WarnBox('Create partners first.')
        else
          for (final p in l.data.partners)
            if (_pct[p.id] != null)
              Row(
                children: [
                  Expanded(
                    child: Text(p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _pct[p.id],
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(hintText: '0', suffixText: '%'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
        LabeledField(
            label: 'Reason (optional)',
            child: TextField(
              controller: _note,
              decoration:
                  const InputDecoration(hintText: 'Why the shares changed'),
            )),
        PreviewBox(children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(message,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: ok ? cs.primary : cs.error)),
                  ],
                ),
              ),
              Text(
                '${(total / 100).toStringAsFixed(2)}%',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ok ? cs.primary : cs.error),
              ),
            ],
          ),
        ]),
        Text(
          'Leave a partner blank to keep them off this site. To hand one share to someone else unchanged, use Replace partner.',
          style: TextStyle(fontSize: 12, color: mutedColor(context)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- new site / partner

class NewSiteDialog extends StatefulWidget {
  const NewSiteDialog({super.key});

  @override
  State<NewSiteDialog> createState() => _NewSiteDialogState();
}

class _NewSiteDialogState extends State<NewSiteDialog> with SaveMixin {
  final _name = TextEditingController();
  final _location = TextEditingController();
  String _start = todayIso();

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogFrame(
      title: 'New site',
      subtitle:
          'Add the site first. Partners and percentages are set on the next step.',
      cta: 'Save and set shares',
      error: error,
      onSave: () {
        final cubit = context.read<LedgerCubit>();
        final nav = context.read<NavCubit>();
        final navigator = Navigator.of(context);
        int? id;
        run(
          () async {
            id = await cubit.addSite(
                name: _name.text, location: _location.text, startDate: _start);
          },
          'Site added',
          after: () {
            final siteId = id;
            if (siteId == null) return;
            nav.go(AppRoute.site(siteId));
            showDialog<void>(
              context: navigator.context,
              builder: (_) => EditSharesDialog(siteId: siteId),
            );
          },
        );
      },
      children: [
        LabeledField(
            label: 'Site name',
            child: TextField(
              controller: _name,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'e.g. Green Valley Plots'),
            )),
        FieldRow([
          LabeledField(
              label: 'Location (optional)',
              child: TextField(
                controller: _location,
                decoration: const InputDecoration(hintText: 'Area or address'),
              )),
          DateField(
            label: 'Start date',
            value: _start,
            onChanged: (v) => setState(() => _start = v),
          ),
        ]),
      ],
    );
  }
}

class NewPartnerDialog extends StatefulWidget {
  const NewPartnerDialog({super.key});

  @override
  State<NewPartnerDialog> createState() => _NewPartnerDialogState();
}

class _NewPartnerDialogState extends State<NewPartnerDialog> with SaveMixin {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _company = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogFrame(
      title: 'New partner',
      subtitle:
          'One profile per person. The same partner can be on any number of sites.',
      cta: 'Save partner',
      error: error,
      onSave: () => run(
        () => context.read<LedgerCubit>().addPartner(
            name: _name.text, phone: _phone.text, isCompany: _company),
        'Partner added',
      ),
      children: [
        FieldRow([
          LabeledField(
              label: 'Name',
              child: TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Full name'),
              )),
          LabeledField(
              label: 'Phone (optional)',
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Mobile number'),
              )),
        ]),
        CheckboxListTile(
          value: _company,
          onChanged: (v) => setState(() => _company = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('This is the company'),
          subtitle: const Text(
              'The company invests and takes a share like any other partner.'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- reverse

class ReverseDialog extends StatefulWidget {
  final Entry entry;
  const ReverseDialog({super.key, required this.entry});

  @override
  State<ReverseDialog> createState() => _ReverseDialogState();
}

class _ReverseDialogState extends State<ReverseDialog> with SaveMixin {
  @override
  Widget build(BuildContext context) {
    final l = _ledgerOf(context);
    final e = widget.entry;
    return DialogFrame(
      title: 'Reverse this entry?',
      subtitle:
          'A reversal adds an opposite entry dated today. The original stays in the list, marked Reversed.',
      cta: 'Reverse entry',
      error: error,
      onSave: () => run(
          () => context.read<LedgerCubit>().reverse(e.id), 'Entry reversed'),
      children: [
        PreviewBox(children: [
          PreviewLine(Text('${formatDate(e.date)} · ${l.siteName(e.siteId)}'),
              [Text(kindLabel(e))]),
          Text(entryDetail(l, e)),
          const SizedBox(height: 6),
          if (e.kind == EntryKind.incomeExpense)
            PreviewLine(Text('Income ${formatCell(e.income)}'),
                [Text('Expense ${formatCell(e.expense)}')])
          else if (e.allocations.isNotEmpty)
            PreviewLine(
                const Text('Amount'), [MoneyText(e.allocations.first.amount)]),
        ]),
        if (e.groupId != null)
          Text('Both sides of the transfer are reversed together.',
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
      ],
    );
  }
}
