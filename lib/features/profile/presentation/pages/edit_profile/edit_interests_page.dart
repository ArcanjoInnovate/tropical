// lib/features/profile/presentation/pages/edit_profile/edit_interests_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/profile/controller/edit_interests_controller.dart';
import 'package:tabuapp/features/profile/data/repositories/interests_repository.dart';
import 'package:tabuapp/features/profile/data/services/interests_service.dart';
import 'package:tabuapp/features/profile/presentation/widgets/edit_profile_shareds.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MODELO DE DADOS
// ════════════════════════════════════════════════════════════════════════════

class InterestCategory {
  const InterestCategory({
    required this.id,
    required this.emoji,
    required this.label,
    required this.items,
  });

  final String       id;
  final String       emoji;
  final String       label;
  final List<String> items;
}

// ════════════════════════════════════════════════════════════════════════════
//  CATÁLOGO DE INTERESSES
// ════════════════════════════════════════════════════════════════════════════

const List<InterestCategory> kInterestCategories = [
  InterestCategory(
    id: 'musica', emoji: '🎵', label: 'Música',
    items: [
      'Rock','Pop','Sertanejo','Funk','Rap','Trap','MPB','Gospel',
      'Eletrônica','Jazz','Blues','Reggae','K-pop','Pagode','Samba',
      'Forró','Indie','Música Clássica','Metal','Lo-fi',
    ],
  ),
  InterestCategory(
    id: 'filmes', emoji: '🎬', label: 'Filmes e Séries',
    items: [
      'Marvel','DC','Anime','Terror','Suspense','Romance','Comédia',
      'Ficção Científica','Drama','Ação','Documentários','Fantasia',
      'Netflix','Cinema Nacional','Sitcoms','Doramas','Star Wars',
      'Harry Potter','The Walking Dead','Stranger Things',
    ],
  ),
  InterestCategory(
    id: 'leitura', emoji: '📚', label: 'Leitura',
    items: [
      'Romance','Fantasia','Ficção Científica','Desenvolvimento Pessoal',
      'Finanças','Negócios','História','Filosofia','Psicologia',
      'Mangás','HQs','Biografias','Religião','Tecnologia','Mistério',
    ],
  ),
  InterestCategory(
    id: 'games', emoji: '🎮', label: 'Games',
    items: [
      'FPS','MMORPG','RPG','MOBA','Battle Royale','Minecraft','Roblox',
      'GTA','Valorant','Counter-Strike','League of Legends','Dota 2',
      'Free Fire','Call of Duty','EA FC','Fortnite','Pokémon',
      'Jogos Mobile','Jogos Indie','Jogos Retro',
    ],
  ),
  InterestCategory(
    id: 'esportes', emoji: '🏋️', label: 'Esportes e Fitness',
    items: [
      'Academia','Calistenia','Corrida','Caminhada','Futebol','Basquete',
      'Vôlei','Natação','Ciclismo','Crossfit','Yoga','Muay Thai',
      'Jiu-Jitsu','Boxe','Skate','Surf','Trilha','Escalada','Tênis','Pilates',
    ],
  ),
  InterestCategory(
    id: 'viagens', emoji: '✈️', label: 'Viagens',
    items: [
      'Praia','Montanha','Mochilão','Viagens Internacionais','Ecoturismo',
      'Camping','Resorts','Cruzeiros','Turismo Histórico','Road Trips',
      'Cachoeiras','Parques Nacionais',
    ],
  ),
  InterestCategory(
    id: 'gastronomia', emoji: '🍕', label: 'Gastronomia',
    items: [
      'Churrasco','Hambúrguer','Pizza','Sushi','Comida Japonesa',
      'Comida Italiana','Comida Mexicana','Comida Árabe','Cafés','Doces',
      'Culinária Fitness','Cozinhar','Vinhos','Cervejas Artesanais','Chocolates',
    ],
  ),
  InterestCategory(
    id: 'animais', emoji: '🐶', label: 'Animais',
    items: [
      'Cachorros','Gatos','Aves','Cavalos','Animais Exóticos',
      'Resgate Animal','Aquarismo',
    ],
  ),
  InterestCategory(
    id: 'tecnologia', emoji: '💻', label: 'Tecnologia',
    items: [
      'Programação','Inteligência Artificial','Startups','Cybersegurança',
      'Hardware','Android','iPhone','Desenvolvimento Web',
      'Desenvolvimento Mobile','Open Source','Automação','Blockchain',
      'Criptomoedas',
    ],
  ),
  InterestCategory(
    id: 'negocios', emoji: '💰', label: 'Negócios e Carreira',
    items: [
      'Empreendedorismo','Marketing Digital','Investimentos',
      'Bolsa de Valores','Economia','Vendas','Liderança','Networking',
      'Gestão','E-commerce','Finanças Pessoais','Trading',
    ],
  ),
  InterestCategory(
    id: 'devpessoal', emoji: '🧠', label: 'Desenvolvimento Pessoal',
    items: [
      'Meditação','Produtividade','Oratória','Psicologia','Filosofia',
      'Hábitos','Disciplina','Autoconhecimento','Inteligência Emocional',
      'Leitura Diária',
    ],
  ),
  InterestCategory(
    id: 'arte', emoji: '🎨', label: 'Arte e Criatividade',
    items: [
      'Desenho','Pintura','Fotografia','Design Gráfico','Escrita',
      'Teatro','Dança','Artesanato','Música','Produção de Conteúdo',
    ],
  ),
  InterestCategory(
    id: 'religiao', emoji: '🙏', label: 'Religião e Espiritualidade',
    items: [
      'Cristianismo','Catolicismo','Protestantismo','Estudos Bíblicos',
      'Oração','Voluntariado','Espiritualidade','Teologia',
    ],
  ),
  InterestCategory(
    id: 'lifestyle', emoji: '🌳', label: 'Estilo de Vida',
    items: [
      'Vida no Campo','Minimalismo','Sustentabilidade','Jardinagem',
      'Organização','DIY (Faça Você Mesmo)','Casa e Decoração',
      'Moda','Carros','Motos',
    ],
  ),
  InterestCategory(
    id: 'relacionamentos', emoji: '❤️', label: 'Relacionamentos',
    items: [
      'Casamento','Namoro Sério','Família','Filhos','Comunicação',
      'Romance','Desenvolvimento em Casal',
    ],
  ),
  InterestCategory(
    id: 'lazer', emoji: '🎉', label: 'Lazer',
    items: [
      'Festas','Baladas','Karaokê','Jogos de Tabuleiro','Escape Room',
      'Barzinhos','Cinema','Shows','Eventos Geek','Feiras',
    ],
  ),
];

// ════════════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════════════

class EditInterestsPage extends StatefulWidget {
  const EditInterestsPage({super.key, required this.userData});

  /// Snapshot completo de Users/{uid} — precisa conter 'interests' se já houver.
  final Map<String, dynamic> userData;

  @override
  State<EditInterestsPage> createState() => _EditInterestsPageState();
}

class _EditInterestsPageState extends State<EditInterestsPage>
    with TickerProviderStateMixin {

  late final EditInterestsController _controller;

  // Controla qual categoria está expandida no painel lateral
  int _activeCatIndex = 0;

  final _catScrollCtrl   = ScrollController();
  final _chipsScrollCtrl = ScrollController();

  // ── Init ───────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _controller = EditInterestsController(
      service: InterestsService(
        repository: InterestsRepository(db: FirebaseDatabase.instance),
      ),
      userData: widget.userData,
    )..addListener(_onControllerChange);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChange)
      ..dispose();
    _catScrollCtrl.dispose();
    _chipsScrollCtrl.dispose();
    super.dispose();
  }

  // ── Listener ──────────────────────────────────────────────────────────────

  void _onControllerChange() {
    if (!mounted) return;

    if (_controller.saveStatus == InterestsSaveStatus.success) {
      Navigator.pop(context, {
        'interests': _controller.selected.toList(),
      });
      return;
    }

    if (_controller.saveStatus == InterestsSaveStatus.error) {
      _snack(_controller.saveError ?? 'Erro ao salvar');
      _controller.resetSaveStatus();
    }

    setState(() {});
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _toggle(String item) {
    HapticFeedback.selectionClick();
    final added = _controller.toggle(item);
    if (!added) _showLimitSnack();
  }

  void _showLimitSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Máximo de $kMaxInterests interesses atingido.',
          style: const TextStyle(
            fontFamily: 'Barlow Condensed',
            fontSize: 13,
            letterSpacing: 1.4,
            color: TabuColors.errorLight,
          ),
        ),
        backgroundColor: TabuColors.errorDeep,
        behavior:        SnackBarBehavior.floating,
        shape:           const RoundedRectangleBorder(),
        duration:        const Duration(seconds: 2),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF3D0A0A),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      content: Text(
        msg.toUpperCase(),
        style: const TextStyle(
          fontFamily: TabuTypography.bodyFont,
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 2, color: TabuColors.textoPrincipal,
        ),
      ),
    ));
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _save() {
    if (_controller.isSaving) return;
    FocusScope.of(context).unfocus();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _snack('Usuário não autenticado');
      return;
    }

    _controller.save(uid);
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return EditPageScaffold(
      title:  'INTERESSES',
      onSave: _controller.isSaving ? null : _save,
      busy:   _controller.isSaving,
      child:  _buildBody(),
    );
  }

  Widget _buildBody() {
    final selected = _controller.selected;

    return Column(
      children: [
        _CounterBar(selected: _controller.count, max: kMaxInterests),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Painel esquerdo: categorias ─────────────────────────────
              _CategoryPanel(
                categories:     kInterestCategories,
                activeCatIndex: _activeCatIndex,
                selected:       selected,
                scrollCtrl:     _catScrollCtrl,
                onSelect:       (i) => setState(() => _activeCatIndex = i),
              ),
              Container(width: 0.5, color: TabuColors.border),
              // ── Painel direito: chips ───────────────────────────────────
              Expanded(
                child: _ChipsPanel(
                  category:   kInterestCategories[_activeCatIndex],
                  selected:   selected,
                  scrollCtrl: _chipsScrollCtrl,
                  onToggle:   _toggle,
                ),
              ),
            ],
          ),
        ),
        if (selected.isNotEmpty)
          _SelectedBar(selected: selected, onRemove: _toggle),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  COUNTER BAR
// ════════════════════════════════════════════════════════════════════════════

class _CounterBar extends StatelessWidget {
  const _CounterBar({required this.selected, required this.max});
  final int selected;
  final int max;

  @override
  Widget build(BuildContext context) {
    final pct      = selected / max;
    final isAtMax  = selected >= max;
    final barColor = isAtMax ? TabuColors.error : TabuColors.rosaPrincipal;

    return Container(
      color:   TabuColors.bgAlt,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SEUS INTERESSES',
                style: TextStyle(
                  fontFamily: 'Barlow Condensed',
                  fontSize:   9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: TabuColors.subtle,
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 12, letterSpacing: 1),
                  children: [
                    TextSpan(
                      text:  '$selected',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isAtMax ? TabuColors.error : TabuColors.textoPrincipal,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text:  ' / $max',
                      style: const TextStyle(color: TabuColors.subtle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: TweenAnimationBuilder<double>(
              tween:    Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 300),
              curve:    Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value:           value,
                minHeight:       2.5,
                backgroundColor: TabuColors.border,
                valueColor:      AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAINEL DE CATEGORIAS (esquerdo)
// ════════════════════════════════════════════════════════════════════════════

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.categories,
    required this.activeCatIndex,
    required this.selected,
    required this.scrollCtrl,
    required this.onSelect,
  });

  final List<InterestCategory> categories;
  final int                    activeCatIndex;
  final Set<String>            selected;
  final ScrollController       scrollCtrl;
  final void Function(int)     onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: ListView.builder(
        controller:  scrollCtrl,
        itemCount:   categories.length,
        itemBuilder: (_, i) {
          final cat      = categories[i];
          final isActive = i == activeCatIndex;
          final selCount = cat.items.where(selected.contains).length;

          return _CatItem(
            emoji:     cat.emoji,
            label:     cat.label,
            isActive:  isActive,
            selCount:  selCount,
            onTap:     () => onSelect(i),
          );
        },
      ),
    );
  }
}

class _CatItem extends StatelessWidget {
  const _CatItem({
    required this.emoji,
    required this.label,
    required this.isActive,
    required this.selCount,
    required this.onTap,
  });

  final String       emoji;
  final String       label;
  final bool         isActive;
  final int          selCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        decoration: BoxDecoration(
          color: isActive
              ? TabuColors.rosaPrincipal.withOpacity(0.12)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? TabuColors.rosaPrincipal : Colors.transparent,
              width: 2.5,
            ),
            bottom: BorderSide(color: TabuColors.border.withOpacity(0.4), width: 0.5),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign:  TextAlign.center,
              maxLines:   2,
              overflow:   TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily:  'Barlow Condensed',
                fontSize:    9.5,
                fontWeight:  isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.8,
                height:      1.3,
                color: isActive ? TabuColors.rosaPrincipal : TabuColors.dim,
              ),
            ),
            if (selCount > 0) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color:        TabuColors.rosaPrincipal.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: TabuColors.rosaPrincipal.withOpacity(0.40),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  '$selCount',
                  style: const TextStyle(
                    fontFamily:  'Barlow Condensed',
                    fontSize:    9,
                    fontWeight:  FontWeight.w700,
                    color:       TabuColors.rosaPrincipal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAINEL DE CHIPS (direito)
// ════════════════════════════════════════════════════════════════════════════

class _ChipsPanel extends StatelessWidget {
  const _ChipsPanel({
    required this.category,
    required this.selected,
    required this.scrollCtrl,
    required this.onToggle,
  });

  final InterestCategory      category;
  final Set<String>           selected;
  final ScrollController      scrollCtrl;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollCtrl,
      physics:    const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.label.toUpperCase(),
                    style: const TextStyle(
                      fontFamily:   'Barlow Condensed',
                      fontSize:     13,
                      fontWeight:   FontWeight.w700,
                      letterSpacing: 3,
                      color:        TabuColors.textoPrincipal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing:     8,
              runSpacing:  8,
              children: category.items.map((item) {
                final isSel = selected.contains(item);
                return _InterestChip(
                  label:      item,
                  isSelected: isSel,
                  onTap:      () => onToggle(item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CHIP DE INTERESSE
// ════════════════════════════════════════════════════════════════════════════

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String       label;
  final bool         isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve:    Curves.easeOut,
        padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? TabuColors.rosaPrincipal.withOpacity(0.20)
              : TabuColors.bgCard,
          border: Border.all(
            color: isSelected ? TabuColors.rosaPrincipal : TabuColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:      TabuColors.rosaPrincipal.withOpacity(0.18),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded,
                  size: 11, color: TabuColors.rosaPrincipal),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily:  'Barlow Condensed',
                fontSize:    12,
                fontWeight:  isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.6,
                color: isSelected ? TabuColors.rosaPrincipal : TabuColors.dim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BARRA INFERIOR — interesses selecionados
// ════════════════════════════════════════════════════════════════════════════

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({required this.selected, required this.onRemove});
  final Set<String>            selected;
  final void Function(String)  onRemove;

  @override
  Widget build(BuildContext context) {
    final items = selected.toList();

    return Container(
      decoration: BoxDecoration(
        color: TabuColors.bgAlt,
        border: Border(top: BorderSide(color: TabuColors.border, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color:      TabuColors.rosaPrincipal.withOpacity(0.06),
            blurRadius: 16,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'SELECIONADOS',
              style: TextStyle(
                fontFamily:   'Barlow Condensed',
                fontSize:     8,
                fontWeight:   FontWeight.w700,
                letterSpacing: 3,
                color:        TabuColors.subtle,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics:         const BouncingScrollPhysics(),
              itemCount:       items.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child:   _MiniChip(label: items[i], onRemove: () => onRemove(items[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.onRemove});
  final String       label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [TabuColors.rosaDeep, TabuColors.rosaPrincipal],
          ),
          boxShadow: [
            BoxShadow(
              color:      TabuColors.rosaPrincipal.withOpacity(0.25),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily:   'Barlow Condensed',
                fontSize:     11,
                fontWeight:   FontWeight.w700,
                letterSpacing: 0.5,
                color:        TabuColors.textoPrincipal,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.close_rounded,
                size: 11, color: TabuColors.rosaClaro),
          ],
        ),
      ),
    );
  }
}