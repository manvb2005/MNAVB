import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firebase_service.dart';
import '../utils/currency_formatter.dart';

class _BankOption {
  final String nombre;
  final String logo;

  const _BankOption({required this.nombre, required this.logo});
}

const _bankOptions = <_BankOption>[
  _BankOption(
    nombre: 'BBVA',
    logo:
        'https://pps.services.adobe.com/api/profile/F1913DDA5A3BC47C0A495C08@AdobeID/image/b6c20c0d-0e3c-4e8e-9b60-c02ccf1cb54d/276',
  ),
  _BankOption(
    nombre: 'BCP',
    logo: 'https://www.epsgrau.pe/webpage/oficinavirtual/oficinas-pago/img/bcp.png',
  ),
  _BankOption(
    nombre: 'SCOTIABANK',
    logo: 'https://images.icon-icons.com/2699/PNG/512/scotiabank_logo_icon_170755.png',
  ),
  _BankOption(
    nombre: 'INTERBANK',
    logo: 'https://www.fabritec.pe/assets/media/logo-banco/logo-inter.png',
  ),
  _BankOption(
    nombre: 'YAPE',
    logo:
        'https://d1yjjnpx0p53s8.cloudfront.net/styles/logo-thumbnail/s3/032021/yape.png?nfeyt9DPqyQFYu7MebAfT.qYz11ytffk&itok=vkI2T5X4',
  ),
  _BankOption(
    nombre: 'PLIN',
    logo: 'https://images.seeklogo.com/logo-png/38/2/plin-logo-png_seeklogo-386806.png',
  ),
];

class CreditCardsView extends StatefulWidget {
  const CreditCardsView({super.key});

  @override
  State<CreditCardsView> createState() => _CreditCardsViewState();
}

class _CreditCardsViewState extends State<CreditCardsView> {
  final _service = FirebaseService();

  final _numberCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _BankOption? _selectedBank;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBank = _bankOptions.first;
    _numberCtrl.addListener(_onPreviewChange);
    _nameCtrl.addListener(_onPreviewChange);
    _expiryCtrl.addListener(_onPreviewChange);
  }

  @override
  void dispose() {
    _numberCtrl
      ..removeListener(_onPreviewChange)
      ..dispose();
    _cvvCtrl.dispose();
    _expiryCtrl
      ..removeListener(_onPreviewChange)
      ..dispose();
    _nameCtrl
      ..removeListener(_onPreviewChange)
      ..dispose();
    _dniCtrl.dispose();
    super.dispose();
  }

  void _onPreviewChange() {
    if (mounted) setState(() {});
  }

  String _cardNumberPreview() {
    final digits = _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '0000 0000 0000 0000';
    final chunks = <String>[];
    for (var i = 0; i < digits.length; i += 4) {
      final end = (i + 4) > digits.length ? digits.length : (i + 4);
      chunks.add(digits.substring(i, end));
    }
    return chunks.join(' ');
  }

  String _cardNumberMasked(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '****';
    final tail = digits.substring(digits.length - 4);
    return '**** **** **** $tail';
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank == null) return;

    setState(() => _saving = true);
    try {
      await _service.agregarTarjetaCredito(
        bancoNombre: _selectedBank!.nombre,
        bancoLogo: _selectedBank!.logo,
        numeroTarjeta: _numberCtrl.text,
        cvv: _cvvCtrl.text,
        fechaCaducidad: _expiryCtrl.text,
        nombreTitular: _nameCtrl.text,
        dniTitular: _dniCtrl.text,
      );

      _numberCtrl.clear();
      _cvvCtrl.clear();
      _expiryCtrl.clear();
      _nameCtrl.clear();
      _dniCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarjeta guardada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openExtraInfoSheet(Map<String, dynamic> card) async {
    final corteCtrl = TextEditingController(
      text: (card['diaCorte'] as int?)?.toString() ?? '',
    );
    final pagoCtrl = TextEditingController(
      text: (card['diaPago'] as int?)?.toString() ?? '',
    );
    final lineaCtrl = TextEditingController(
      text: formatAmount((card['lineaCredito'] as num?) ?? 0),
    );
    final deudaCtrl = TextEditingController(
      text: formatAmount((card['deudaActual'] as num?) ?? 0),
    );
    final minimoCtrl = TextEditingController(
      text: formatAmount((card['pagoMinimo'] as num?) ?? 0),
    );

    final key = GlobalKey<FormState>();
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF14151A) : Colors.white;
        final border = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border.all(color: border),
                  ),
                  child: Form(
                    key: key,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Info de tarjeta',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _NumberField(
                            controller: corteCtrl,
                            label: 'Dia de corte',
                            maxLen: 2,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final n = int.tryParse(v);
                              if (n == null || n < 1 || n > 31) {
                                return 'Dia invalido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _NumberField(
                            controller: pagoCtrl,
                            label: 'Dia de pago',
                            maxLen: 2,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final n = int.tryParse(v);
                              if (n == null || n < 1 || n > 31) {
                                return 'Dia invalido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _MoneyField(
                            controller: lineaCtrl,
                            label: 'Linea de credito',
                          ),
                          const SizedBox(height: 10),
                          _MoneyField(
                            controller: deudaCtrl,
                            label: 'Deuda actual',
                          ),
                          const SizedBox(height: 10),
                          _MoneyField(
                            controller: minimoCtrl,
                            label: 'Pago minimo',
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: saving
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          if (!key.currentState!.validate()) {
                                            return;
                                          }
                                          setSheetState(() => saving = true);
                                          try {
                                            await _service
                                                .actualizarInfoTarjetaCredito(
                                                  tarjetaId: card['id'] as String,
                                                  diaCorte: int.tryParse(
                                                    corteCtrl.text.trim(),
                                                  ),
                                                  diaPago: int.tryParse(
                                                    pagoCtrl.text.trim(),
                                                  ),
                                                  lineaCredito: _parseMoney(
                                                    lineaCtrl.text,
                                                  ),
                                                  deudaActual: _parseMoney(
                                                    deudaCtrl.text,
                                                  ),
                                                  pagoMinimo: _parseMoney(
                                                    minimoCtrl.text,
                                                  ),
                                                );
                                            if (!mounted) return;
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Informacion actualizada',
                                                    ),
                                                  ),
                                                );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e
                                                          .toString()
                                                          .replaceAll(
                                                            'Exception: ',
                                                            '',
                                                          ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.red.shade600,
                                                  ),
                                                );
                                          } finally {
                                            if (mounted) {
                                              setSheetState(
                                                () => saving = false,
                                              );
                                            }
                                          }
                                        },
                                  child: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Guardar'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    corteCtrl.dispose();
    pagoCtrl.dispose();
    lineaCtrl.dispose();
    deudaCtrl.dispose();
    minimoCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.52);

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tarjeta de credito',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Guarda tus tarjetas y su info de pagos.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 18),
                  children: [
                    _CreditCardPreview(
                      bankName: _selectedBank?.nombre ?? 'BANCO',
                      bankLogo: _selectedBank?.logo,
                      number: _cardNumberPreview(),
                      holder: _nameCtrl.text.trim().isEmpty
                          ? 'NOMBRE TITULAR'
                          : _nameCtrl.text.trim().toUpperCase(),
                      expiry: _expiryCtrl.text.trim().isEmpty
                          ? 'MM/YY'
                          : _expiryCtrl.text.trim(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            DropdownButtonFormField<_BankOption>(
                              initialValue: _selectedBank,
                              decoration: const InputDecoration(
                                labelText: 'Banco',
                              ),
                              items: _bankOptions
                                  .map(
                                    (e) => DropdownMenuItem<_BankOption>(
                                      value: e,
                                      child: Text(e.nombre),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedBank = v),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _numberCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(19),
                                _CardNumberInputFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Numero de tarjeta',
                              ),
                              validator: (v) {
                                final digits =
                                    (v ?? '').replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 13) {
                                  return 'Numero invalido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cvvCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'CVV',
                                    ),
                                    validator: (v) {
                                      final digits = (v ?? '').replaceAll(
                                        RegExp(r'\D'),
                                        '',
                                      );
                                      if (digits.length < 3) {
                                        return 'CVV invalido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _expiryCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(4),
                                      _ExpiryInputFormatter(),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Caducidad MM/YY',
                                    ),
                                    validator: (v) {
                                      if (v == null ||
                                          !RegExp(
                                            r'^(0[1-9]|1[0-2])\/\d{2}$',
                                          ).hasMatch(v)) {
                                        return 'Fecha invalida';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre completo',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Campo obligatorio';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _dniCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(8),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'DNI',
                              ),
                              validator: (v) {
                                if (!RegExp(r'^\d{8}$').hasMatch(v ?? '')) {
                                  return 'DNI invalido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _saveCard,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.credit_card_rounded),
                                label: Text(
                                  _saving ? 'Guardando...' : 'Agregar tarjeta',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mis tarjetas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _service.getTarjetasCreditoStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final cards = snapshot.data ?? [];
                        if (cards.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: border),
                            ),
                            child: Text(
                              'Aun no tienes tarjetas registradas.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: muted,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: cards.map((card) {
                            final line =
                                (card['lineaCredito'] as num?)?.toDouble() ?? 0;
                            final debt =
                                (card['deudaActual'] as num?)?.toDouble() ?? 0;
                            final minimum =
                                (card['pagoMinimo'] as num?)?.toDouble() ?? 0;
                            final available = line - debt;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.06),
                                          ),
                                          child: ClipOval(
                                            child: Image.network(
                                              (card['bancoLogo'] as String?) ??
                                                  '',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.account_balance,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                (card['bancoNombre'] as String?) ??
                                                    '-',
                                                style: theme
                                                    .textTheme.titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                              ),
                                              Text(
                                                _cardNumberMasked(
                                                  (card['numeroTarjeta']
                                                          as String?) ??
                                                      '',
                                                ),
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(color: muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _openExtraInfoSheet(card),
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Agregar info'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _InfoPill(
                                          label: 'Linea: ${formatMoney(line)}',
                                        ),
                                        _InfoPill(
                                          label:
                                              'Deuda: ${formatMoney(debt)}',
                                        ),
                                        _InfoPill(
                                          label:
                                              'Disponible: ${formatMoney(available < 0 ? 0 : available)}',
                                        ),
                                        _InfoPill(
                                          label:
                                              'Pago minimo: ${formatMoney(minimum)}',
                                        ),
                                        _InfoPill(
                                          label:
                                              'Corte: ${(card['diaCorte'] as int?)?.toString() ?? '-'}',
                                        ),
                                        _InfoPill(
                                          label:
                                              'Pago: ${(card['diaPago'] as int?)?.toString() ?? '-'}',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditCardPreview extends StatelessWidget {
  final String bankName;
  final String? bankLogo;
  final String number;
  final String holder;
  final String expiry;

  const _CreditCardPreview({
    required this.bankName,
    required this.bankLogo,
    required this.number,
    required this.holder,
    required this.expiry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stroke = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: stroke),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E232F), const Color(0xFF0F1117)]
              : [const Color(0xFF20242D), const Color(0xFF0D0F15)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.25),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
                child: ClipOval(
                  child: Image.network(
                    bankLogo ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_balance_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bankName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.credit_card_rounded, color: Colors.white),
            ],
          ),
          const Spacer(),
          Text(
            number,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PreviewMeta(label: 'Titular', value: holder),
              ),
              _PreviewMeta(label: 'Expira', value: expiry),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewMeta extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.70),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;

  const _InfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) out.write(' ');
      out.write(digits[i]);
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final month = digits.length >= 2 ? digits.substring(0, 2) : digits;
    final year = digits.length > 2 ? digits.substring(2, digits.length) : '';
    final text = year.isEmpty ? month : '$month/$year';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLen;
  final String? Function(String?)? validator;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.maxLen,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLen),
      ],
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}

class _MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _MoneyField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,\.]'))],
      onEditingComplete: () {
        final value = _parseMoney(controller.text);
        controller.value = TextEditingValue(
          text: formatAmount(value),
          selection: TextSelection.collapsed(offset: formatAmount(value).length),
        );
      },
      decoration: InputDecoration(labelText: label, prefixText: 'S/ '),
    );
  }
}

double _parseMoney(String raw) {
  var value = raw.trim().replaceAll(' ', '');
  if (value.isEmpty) return 0;

  if (value.contains(',') && value.contains('.')) {
    value = value.replaceAll(',', '');
  } else if (value.contains(',') && !value.contains('.')) {
    final parts = value.split(',');
    if (parts.length == 2 && parts[1].length <= 2) {
      value = '${parts[0]}.${parts[1]}';
    } else {
      value = value.replaceAll(',', '');
    }
  }

  return double.tryParse(value) ?? 0;
}
