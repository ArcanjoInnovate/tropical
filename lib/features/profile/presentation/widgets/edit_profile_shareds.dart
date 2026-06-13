// lib/screens/screens_home/perfil_screen/edit_perfil/edit_perfil_shared.dart
import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE SCAFFOLD  (header padrão + background de todas as sub-telas)
// ════════════════════════════════════════════════════════════════════════════
class EditPageScaffold extends StatelessWidget {
  const EditPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onSave,
    this.saveLabel = 'SALVAR',
    this.busy      = false,
  });

  final String       title;
  final Widget       child;
  final VoidCallback? onSave;
  final String       saveLabel;
  final bool         busy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Stack(children: [
        const Positioned.fill(child: _BgPaint()),
        Positioned(top: 0, left: 0, right: 0, child: Container(
          height: 3,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [
            TabuColors.rosaDeep, TabuColors.rosaPrincipal,
            TabuColors.rosaClaro, TabuColors.rosaPrincipal, TabuColors.rosaDeep,
          ])),
        )),
        SafeArea(child: Column(children: [
          _EditHeader(title: title, onSave: onSave, busy: busy, saveLabel: saveLabel),
          Container(height: 0.5, color: TabuColors.border),
          Expanded(child: child),
        ])),
      ]),
    );
  }
}

// ── header ────────────────────────────────────────────────────────────────
class _EditHeader extends StatelessWidget {
  const _EditHeader({
    required this.title,
    required this.busy,
    required this.saveLabel,
    this.onSave,
  });

  final String       title;
  final bool         busy;
  final String       saveLabel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: TabuColors.dim, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(child: Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: TabuTypography.displayFont,
            fontSize: 16, letterSpacing: 4, color: TabuColors.textoPrincipal,
          ))),
        if (onSave != null)
          GestureDetector(
            onTap: busy ? null : onSave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:  busy ? TabuColors.bgCard : TabuColors.rosaPrincipal,
                border: Border.all(color: TabuColors.rosaPrincipal, width: 0.8),
              ),
              child: Text(busy ? '...' : saveLabel,
                style: TextStyle(
                  fontFamily: TabuTypography.bodyFont,
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5,
                  color: busy ? TabuColors.subtle : TabuColors.textoPrincipal,
                )),
            ),
          )
        else
          const SizedBox(width: 60),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SECTION LABEL
// ════════════════════════════════════════════════════════════════════════════
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 5, height: 5, decoration: const BoxDecoration(
        color: TabuColors.rosaPrincipal, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(
        fontFamily: TabuTypography.bodyFont, fontSize: 9,
        fontWeight: FontWeight.w700, letterSpacing: 3, color: TabuColors.rosaPrincipal)),
    const SizedBox(width: 12),
    Expanded(child: Container(height: 0.5, color: TabuColors.border)),
  ]);
}

// ════════════════════════════════════════════════════════════════════════════
//  TABU TEXT FIELD
// ════════════════════════════════════════════════════════════════════════════
class TabuField extends StatefulWidget {
  const TabuField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines             = 1,
    this.maxLength,
    this.textCapitalization   = TextCapitalization.none,
    this.keyboardType         = TextInputType.text,
    this.textInputAction      = TextInputAction.next,
    this.validator,
    this.onEditingComplete,
  });

  final TextEditingController      controller;
  final FocusNode                  focusNode;
  final String                     label;
  final String                     hint;
  final IconData                   icon;
  final int                        maxLines;
  final int?                       maxLength;
  final TextCapitalization         textCapitalization;
  final TextInputType              keyboardType;
  final TextInputAction            textInputAction;
  final String? Function(String?)? validator;
  final VoidCallback?              onEditingComplete;

  @override
  State<TabuField> createState() => _TabuFieldState();
}

class _TabuFieldState extends State<TabuField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(widget.icon, size: 14,
            color: _focused ? TabuColors.rosaPrincipal : TabuColors.subtle),
        const SizedBox(width: 6),
        Text(widget.label, style: TextStyle(
            fontFamily: TabuTypography.bodyFont, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 2.5,
            color: _focused ? TabuColors.rosaPrincipal : TabuColors.subtle)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: widget.controller, focusNode: widget.focusNode,
        maxLines: widget.maxLines, maxLength: widget.maxLength,
        textCapitalization: widget.textCapitalization,
        keyboardType: widget.keyboardType, textInputAction: widget.textInputAction,
        validator: widget.validator, onEditingComplete: widget.onEditingComplete,
        style: const TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.5,
            color: TabuColors.textoPrincipal),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 13, color: TabuColors.subtle),
          counterStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 9, color: TabuColors.subtle),
          filled: true, fillColor: TabuColors.bgCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border:             _border(TabuColors.border),
          enabledBorder:      _border(TabuColors.border),
          focusedBorder:      _border(TabuColors.rosaPrincipal, width: 1.5),
          errorBorder:        _border(const Color(0xFFE85D5D)),
          focusedErrorBorder: _border(const Color(0xFFE85D5D), width: 1.5),
          errorStyle: const TextStyle(fontFamily: TabuTypography.bodyFont,
              fontSize: 10, letterSpacing: 1, color: Color(0xFFE85D5D)),
        ),
      ),
    ],
  );

  static OutlineInputBorder _border(Color c, {double width = 0.8}) =>
      OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c, width: width));
}

// ════════════════════════════════════════════════════════════════════════════
//  SELECTION TILE  (tappable row abre bottom-sheet)
// ════════════════════════════════════════════════════════════════════════════
class SelectionTile extends StatelessWidget {
  const SelectionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.hint,
    required this.onTap,
    this.value,
  });

  final String       label;
  final IconData     icon;
  final String       hint;
  final String?      value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: has ? TabuColors.rosaPrincipal : TabuColors.subtle),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5,
            color: has ? TabuColors.rosaPrincipal : TabuColors.subtle)),
      ]),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: TabuColors.bgCard,
            border: Border.all(
                color: has ? TabuColors.rosaPrincipal : TabuColors.border,
                width: has ? 1.5 : 0.8),
          ),
          child: Row(children: [
            Expanded(child: Text(has ? value! : hint,
              style: TextStyle(fontFamily: TabuTypography.bodyFont,
                  fontSize: has ? 15 : 13, fontWeight: has ? FontWeight.w500 : FontWeight.w400,
                  color: has ? TabuColors.textoPrincipal : TabuColors.subtle))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: has ? TabuColors.rosaPrincipal : TabuColors.subtle, size: 20),
          ]),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GENERIC OPTIONS SHEET
// ════════════════════════════════════════════════════════════════════════════
class OptionsSheet<T> extends StatelessWidget {
  const OptionsSheet({
    super.key,
    required this.title,
    required this.options,
    required this.current,
    required this.label,
    required this.onSelect,
  });

  final String             title;
  final List<T>            options;
  final T?                 current;
  final String Function(T) label;
  final ValueChanged<T>    onSelect;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.55, maxChildSize: 0.85,
      builder: (_, ctrl) => Column(children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(width: 36, height: 3,
            decoration: BoxDecoration(color: TabuColors.border, borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
          child: Align(alignment: Alignment.centerLeft, child: SectionLabel(label: title))),
        Container(height: 0.5, color: TabuColors.border),
        Expanded(child: ListView.separated(
          controller: ctrl,
          itemCount: options.length,
          separatorBuilder: (_, __) => Container(height: 0.5, color: TabuColors.border),
          itemBuilder: (_, i) {
            final opt      = options[i];
            final isActive = opt == current;
            return InkWell(
              onTap: () => onSelect(opt),
              child: Container(
                color:   isActive ? TabuColors.rosaPrincipal.withOpacity(0.08) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(children: [
                  Expanded(child: Text(label(opt), style: TextStyle(
                    fontFamily: TabuTypography.bodyFont, fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? TabuColors.rosaPrincipal : TabuColors.textoPrincipal))),
                  if (isActive)
                    const Icon(Icons.check_rounded, color: TabuColors.rosaPrincipal, size: 18),
                ]),
              ),
            );
          },
        )),
      ]),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required T? current,
    required String Function(T) label,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: TabuColors.bgAlt,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => OptionsSheet<T>(
        title: title, options: options, current: current, label: label,
        onSelect: (v) => Navigator.pop(context, v),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  INFO BOX
// ════════════════════════════════════════════════════════════════════════════
class InfoBox extends StatelessWidget {
  const InfoBox({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: TabuColors.rosaPrincipal.withOpacity(0.06),
      border: Border.all(color: TabuColors.border, width: 0.8)),
    child: Row(children: [
      const Icon(Icons.info_outline, color: TabuColors.subtle, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(
          fontFamily: TabuTypography.bodyFont, fontSize: 11,
          letterSpacing: 0.5, color: TabuColors.subtle))),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  SAVE BUTTON
// ════════════════════════════════════════════════════════════════════════════
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.saving, required this.uploading,
      required this.progress, required this.onTap});
  final bool         saving;
  final bool         uploading;
  final double       progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final busy  = saving || uploading;
    final label = uploading ? 'ENVIANDO ${(progress * 100).toInt()}%'
                : saving    ? 'SALVANDO...'
                : 'SALVAR ALTERAÇÕES';
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          color:  busy ? TabuColors.bgCard : TabuColors.rosaPrincipal,
          border: Border.all(color: busy ? TabuColors.border : TabuColors.rosaPrincipal, width: 0.8)),
        child: Stack(alignment: Alignment.center, children: [
          if (uploading)
            Positioned.fill(child: FractionallySizedBox(
              alignment: Alignment.centerLeft, widthFactor: progress,
              child: Container(color: TabuColors.rosaPrincipal.withOpacity(0.25)))),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(
                  color: TabuColors.rosaPrincipal, strokeWidth: 1.5))
            else
              const Icon(Icons.check, color: TabuColors.textoPrincipal, size: 16),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontFamily: TabuTypography.bodyFont,
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 3,
                color: busy ? TabuColors.subtle : TabuColors.textoPrincipal)),
          ]),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BACKGROUND
// ════════════════════════════════════════════════════════════════════════════
class _BgPaint extends StatelessWidget {
  const _BgPaint();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BgPainter());
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = TabuColors.bg);
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.08), size.width * 0.6,
      Paint()..shader = RadialGradient(colors: [
        TabuColors.rosaPrincipal.withOpacity(0.07), Colors.transparent,
      ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.08),
          radius: size.width * 0.6)));
  }
  @override
  bool shouldRepaint(_BgPainter _) => false;
}