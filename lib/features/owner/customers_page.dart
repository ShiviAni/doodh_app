import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formats.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../delivery/quantity_stepper.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hindi = s.lang == AppLanguage.hindi;

    return Scaffold(
      body: StreamBuilder<List<Customer>>(
        stream: sl<CustomerRepository>().watchAll(),
        builder: (context, snap) {
          final customers = snap.data;
          if (customers == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (customers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Sizes.gapLarge),
                child: Text(s.noCustomers, textAlign: TextAlign.center),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: customers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = customers[i];
              return ListTile(
                leading: CircleAvatar(
                  radius: 26,
                  backgroundImage: (c.photoUrl?.isNotEmpty ?? false)
                      ? NetworkImage(c.photoUrl!)
                      : null,
                  child: (c.photoUrl?.isEmpty ?? true)
                      ? Text('${c.routeOrder}')
                      : null,
                ),
                title: Text(
                  c.displayName(hindi: hindi),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: c.active ? null : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  [
                    if (c.houseNo.isNotEmpty) '${s.houseNo} ${c.houseNo}',
                    '${Fmt.litres(c.defaultQtyLitres)} ${s.litre}',
                  ].join('  ·  '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _CustomerEditor.show(context, existing: c),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(s.addCustomer),
        onPressed: () => _CustomerEditor.show(context, existing: null),
      ),
    );
  }
}

/// Add or edit one house.
///
/// The route order field matters more than it looks: it is what puts the
/// delivery cards in walking sequence, so the delivery person never has to
/// search for the house he is standing in front of.
class _CustomerEditor extends StatefulWidget {
  const _CustomerEditor({required this.existing});

  final Customer? existing;

  static Future<void> show(
    BuildContext context, {
    required Customer? existing,
  }) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CustomerEditor(existing: existing),
  );

  @override
  State<_CustomerEditor> createState() => _CustomerEditorState();
}

class _CustomerEditorState extends State<_CustomerEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _nameHi = TextEditingController(
    text: widget.existing?.nameHi ?? '',
  );
  late final _houseNo = TextEditingController(
    text: widget.existing?.houseNo ?? '',
  );
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _order = TextEditingController(
    text: '${widget.existing?.routeOrder ?? 0}',
  );
  late double _qty = widget.existing?.defaultQtyLitres ?? 1.0;
  late bool _active = widget.existing?.active ?? true;

  @override
  void dispose() {
    for (final c in [_name, _nameHi, _houseNo, _phone, _order]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final repo = sl<CustomerRepository>();
    final existing = widget.existing;
    final draft = Customer(
      id: existing?.id ?? '',
      name: _name.text.trim(),
      nameHi: _nameHi.text.trim().isEmpty ? null : _nameHi.text.trim(),
      houseNo: _houseNo.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      photoUrl: existing?.photoUrl,
      defaultQtyLitres: _qty,
      routeOrder: int.tryParse(_order.text.trim()) ?? 0,
      active: _active,
    );

    if (existing == null) {
      await repo.add(draft);
    } else {
      await repo.upsert(draft);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: Sizes.gapLarge,
        right: Sizes.gapLarge,
        top: Sizes.gapLarge,
        bottom: MediaQuery.of(context).viewInsets.bottom + Sizes.gapLarge,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? s.addCustomer : s.edit,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: Sizes.bodyText + 4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Sizes.gapLarge),

            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: s.customerName),
            ),
            const SizedBox(height: Sizes.gap),
            TextField(
              controller: _nameHi,
              decoration: const InputDecoration(labelText: 'नाम (हिन्दी)'),
            ),
            const SizedBox(height: Sizes.gap),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _houseNo,
                    decoration: InputDecoration(labelText: s.houseNo),
                  ),
                ),
                const SizedBox(width: Sizes.gap),
                Expanded(
                  child: TextField(
                    controller: _order,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.routeOrder),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sizes.gap),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: s.phone),
            ),

            const SizedBox(height: Sizes.gapLarge),
            Text(
              s.defaultQty,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            QuantityStepper(
              value: _qty,
              onChanged: (v) => setState(() => _qty = v),
            ),

            const SizedBox(height: Sizes.gap),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.activeCustomer),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),

            const SizedBox(height: Sizes.gap),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(s.save),
              onPressed: _name.text.trim().isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
