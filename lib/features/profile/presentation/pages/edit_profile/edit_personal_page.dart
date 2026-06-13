// lib/screens/screens_home/perfil_screen/edit_perfil/edit_dados_pessoais_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/profile/controller/edit_personal_data_controller.dart';
import 'package:tabuapp/features/profile/data/models/personal_data_model.dart';
import 'package:tabuapp/features/profile/data/repositories/personal_data_repository.dart';
import 'package:tabuapp/features/profile/data/services/personal_data_service.dart';
import 'package:tabuapp/features/profile/presentation/widgets/edit_profile_shareds.dart';

class EditPersonalPage extends StatefulWidget {
  const EditPersonalPage({super.key, required this.userData});

  /// Snapshot completo de Users/{uid} vindo da tela anterior.
  final Map<String, dynamic> userData;

  @override
  State<EditPersonalPage> createState() => _PersonalEditsPageState();
}

class _PersonalEditsPageState extends State<EditPersonalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _bioFocus = FocusNode();
  final _birthFocus = FocusNode();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _birthCtrl;
  late final EditPersonalDataController _controller;

  /// Data de nascimento parseada a partir do campo de texto.
  DateTime? _selectedBirthDate;

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(
      text: widget.userData['name'] as String? ?? '',
    );
    _bioCtrl = TextEditingController(
      text: (widget.userData['bio'] as String? ?? '').trim(),
    );
    _birthCtrl = TextEditingController();
    _birthCtrl.addListener(() => _onBirthDateChanged(_birthCtrl.text));

    // Carrega data de nascimento já salva, se houver.
    final savedBirth = widget.userData['birth_date'] as String?;
    if (savedBirth != null && savedBirth.isNotEmpty) {
      _selectedBirthDate = DateTime.tryParse(savedBirth);
      if (_selectedBirthDate != null) {
        _birthCtrl.text = _birthDateDisplay(_selectedBirthDate!);
      }
    }

    // Composição manual — sem DI externo para manter o padrão do projeto.
    _controller = EditPersonalDataController(
      service: PersonalDataService(
        repository: PersonalDataRepository(db: FirebaseDatabase.instance),
      ),
    );

    _controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _birthCtrl.dispose();
    _nameFocus.dispose();
    _bioFocus.dispose();
    _birthFocus.dispose();
    super.dispose();
  }

  // ── Reações ao estado do controller ─────────────────────────────────────

  void _onControllerChange() {
    if (!mounted) return;

    if (_controller.isSuccess) {
      Navigator.pop(context, {
        'name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        if (_selectedBirthDate != null)
          'birth_date': _birthDateToString(_selectedBirthDate!),
        if (_selectedBirthDate != null)
          'age': PersonalDataModel.calculateAge(_selectedBirthDate),
      });
      return;
    }

    if (_controller.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.errorMessage ?? 'Erro ao salvar.'),
          backgroundColor: TabuTheme.error,
        ),
      );
      _controller.resetStatus();
    }
  }

  // ── Máscara e parse da data ───────────────────────────────────────────────

  void _onBirthDateChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();

    // Só atualiza se realmente mudou — evita loop infinito do listener
    if (_birthCtrl.text != formatted) {
      _birthCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      return; // o listener vai disparar novamente com o texto já formatado
    }

    // Parse
    if (digits.length == 8) {
      final day = int.tryParse(digits.substring(0, 2));
      final month = int.tryParse(digits.substring(2, 4));
      final year = int.tryParse(digits.substring(4, 8));

      if (day != null && month != null && year != null) {
        try {
          final date = DateTime(year, month, day);
          if (date.day == day && date.month == month && date.year == year) {
            setState(() => _selectedBirthDate = date);
            return;
          }
        } catch (_) {}
      }
      setState(() => _selectedBirthDate = null);
    } else {
      setState(() => _selectedBirthDate = null);
    }
  }

  String? _validateBirthDate(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

    // Campo opcional — só valida se algo foi digitado
    if (digits.isEmpty) return null;

    if (digits.length < 8) return 'Data incompleta';
    if (_selectedBirthDate == null) return 'Data inválida';

    final now = DateTime.now();
    final age = now.year -
        _selectedBirthDate!.year -
        ((now.month < _selectedBirthDate!.month ||
                (now.month == _selectedBirthDate!.month &&
                    now.day < _selectedBirthDate!.day))
            ? 1
            : 0);

    if (age < 18) return 'Você precisa ter 18 anos ou mais';
    if (age > 100) return 'Data inválida';

    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Formata DateTime → "yyyy-MM-dd" para persistência.
  String _birthDateToString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  /// Formata DateTime → "DD/MM/YYYY" para exibição na UI.
  String _birthDateDisplay(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year.toString().padLeft(4, '0')}';

  // ── Ação de salvar ───────────────────────────────────────────────────────

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return;
    }

    _controller.save(
      uid: uid,
      name: _nameCtrl.text,
      bio: _bioCtrl.text,
      birthDate: _selectedBirthDate != null
          ? _birthDateToString(_selectedBirthDate!)
          : null,
      age: PersonalDataModel.calculateAge(_selectedBirthDate),
      fullUserData: widget.userData,
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return EditPageScaffold(
          title: 'DADOS PESSOAIS',
          onSave: _controller.isLoading ? null : _save,
          busy: _controller.isLoading,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── IDENTIFICAÇÃO ─────────────────────────────────────
                    const SectionLabel(label: 'IDENTIFICAÇÃO'),
                    const SizedBox(height: 14),
                    TabuField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      label: 'NOME',
                      icon: Icons.person_outline,
                      hint: 'Seu nome',
                      maxLength: 20,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Nome obrigatório'
                          : null,
                      onEditingComplete: () =>
                          FocusScope.of(context).requestFocus(_birthFocus),
                    ),

                    // ── DATA DE NASCIMENTO ────────────────────────────────
                    const SizedBox(height: 24),
                    const SectionLabel(label: 'DATA DE NASCIMENTO'),
                    const SizedBox(height: 14),
                    TabuField(
                      controller: _birthCtrl,
                      focusNode: _birthFocus,
                      label: 'DATA DE NASCIMENTO',
                      icon: Icons.cake_outlined,
                      hint: 'DD/MM/AAAA',
                      maxLength: 10,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: _validateBirthDate,
                      onEditingComplete: () =>
                          FocusScope.of(context).requestFocus(_bioFocus),
                    ),
                    if (_selectedBirthDate != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          '${PersonalDataModel.calculateAge(_selectedBirthDate)} anos',
                          style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize: 12,
                            color: TabuColors.rosaPrincipal,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const InfoBox(
                      text: 'Você precisa ter 18 anos ou mais. '
                          'Sua idade aparece nos matches.',
                    ),

                    // ── BIO ───────────────────────────────────────────────
                    const SizedBox(height: 24),
                    const SectionLabel(label: 'BIO'),
                    const SizedBox(height: 14),
                    TabuField(
                      controller: _bioCtrl,
                      focusNode: _bioFocus,
                      label: 'SOBRE VOCÊ',
                      icon: Icons.edit_note_outlined,
                      hint: 'Conte um pouco sobre você...',
                      maxLines: 5,
                      maxLength: 120,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 8),
                    const InfoBox(
                      text: 'Sua bio aparece no perfil público e nos matches.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
