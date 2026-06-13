// lib/features/match/presentation/pages/match_profile_page.dart

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tabuapp/core/helpers/cloudinary_helper.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/match/controller/match_controller.dart';
import 'package:tabuapp/features/match/data/models/match_filter_model.dart';
import 'package:tabuapp/features/match/data/models/match_profile_model.dart';
import 'package:tabuapp/features/match/data/repositories/match_repository.dart';
import 'package:tabuapp/features/match/data/services/like_me_service.dart';
import 'package:tabuapp/features/match/data/services/match_service.dart';
import 'package:tabuapp/features/match/presentation/pages/match_filter_page.dart';
import 'package:tabuapp/core/services/user_data_notifier.dart';
import 'package:tabuapp/features/match/data/services/match_filter_prefs.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════════════
class MatchProfilePage extends StatefulWidget {
  const MatchProfilePage({super.key});

  @override
  State<MatchProfilePage> createState() => _MatchProfilePageState();
}

class _MatchProfilePageState extends State<MatchProfilePage>
    with SingleTickerProviderStateMixin {

  late final MatchController _ctrl;
  late final AnimationController _exitCtrl;

  double _slideX = 0.0;
  VoidCallback? _pendingAction;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  double? get _myLat =>
      (UserDataNotifier.instance.value['latitude'] as num?)?.toDouble();

  double? get _myLng =>
      (UserDataNotifier.instance.value['longitude'] as num?)?.toDouble();

  MatchLocationSource get _locationSource {
    final data   = UserDataNotifier.instance.value;
    final city   = (data['city']  as String?)?.trim() ?? '';
    final state  = (data['state'] as String?)?.trim() ?? '';
    final hasLat = _myLat != null;
    final hasLng = _myLng != null;

    if (city.isNotEmpty && state.isNotEmpty) return MatchLocationSource.profile;
    if (hasLat && hasLng)                    return MatchLocationSource.profileCoords;
    return MatchLocationSource.none;
  }

  @override
  void initState() {
    super.initState();

    _ctrl = MatchController(
      service: MatchService(repository: MatchRepository()),
    )..addListener(() { if (mounted) setState(() {}); });

    _exitCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 280),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _pendingAction?.call();
          _pendingAction = null;
          _exitCtrl.reset();
          if (mounted) setState(() => _slideX = 0.0);
        }
      });

    _init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final saved = await MatchFilterPrefs.load();
    await _loadProfiles(filter: saved);
  }

  Future<void> _loadProfiles({MatchFilterModel? filter}) async {
    final lat = _myLat;
    final lng = _myLng;

    final baseFilter = filter ?? _ctrl.filter;

    _ctrl.applyFilter(baseFilter);

    final filterHasCoords =
        baseFilter.tipoLocalizacao == TipoLocalizacao.personalizada &&
        baseFilter.lat != null &&
        baseFilter.lng != null;

    final hasCoords = (lat != null && lng != null) || filterHasCoords;

    final safeFilter = baseFilter.copyWith(
      onlyInDistance: hasCoords ? baseFilter.onlyInDistance : false,
    );

    await _ctrl.load(
      myUid:  _myUid,
      myLat:  lat ?? 0.0,
      myLng:  lng ?? 0.0,
      filter: safeFilter,
    );
  }

  Future<void> _onLike() async {
    if (!_ctrl.hasMore || _exitCtrl.isAnimating) return;
    if (_ctrl.isCurrentMyProfile) return;

    final targetUid = _ctrl.current!.uid;

    final wasDisliked = await LikeMeService().hasBeenDislikedBy(
        _myUid, targetUid);
    if (!mounted) return;

    if (wasDisliked) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TabuColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(
              color: TabuColors.border.withOpacity(0.6), width: 0.7)),
          content: Row(children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: TabuColors.textoMuted),
            const SizedBox(width: 10),
            Text('Este perfil não está disponível no momento',
                style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize: 11,
                    letterSpacing: 0.3,
                    color: TabuColors.textoPrincipal,
                    fontWeight: FontWeight.w600)),
          ]),
          duration: const Duration(seconds: 3),
        ),
      );
      _ctrl.skip();
      return;
    }

    HapticFeedback.mediumImpact();
    _pendingAction = () => _ctrl.like();
    setState(() => _slideX = 1.5);
    _exitCtrl.forward();
  }

  void _onDislike() {
    if (!_ctrl.hasMore || _exitCtrl.isAnimating) return;
    if (_ctrl.isCurrentMyProfile) return;
    HapticFeedback.mediumImpact();
    _pendingAction = () => _ctrl.dislike();
    setState(() => _slideX = -1.5);
    _exitCtrl.forward();
  }

  void _onSend() {
    if (!_ctrl.hasMore || _exitCtrl.isAnimating) return;
    if (_ctrl.isCurrentMyProfile) return;
    HapticFeedback.lightImpact();
  }

  void _skipMyCard() {
    if (_exitCtrl.isAnimating) return;
    _ctrl.skip();
  }

  void _showMoreSheet() {
    final profile = _ctrl.current;
    if (profile == null) return;
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(
        profileName: profile.name,
        onReport: () {
          Navigator.pop(context);
        },
        onBlock: () {
          Navigator.pop(context);
          _ctrl.advance();
        },
      ),
    );
  }

  Future<void> _openFilter() async {
    final result = await Navigator.push<MatchFilterModel>(
      context,
      MaterialPageRoute(
        builder: (_) => MatchFilterPage(
          initialFilter:  _ctrl.filter,
          locationSource: _locationSource,
        ),
      ),
    );
    if (result != null && mounted) {
      await MatchFilterPrefs.save(result);
      await _loadProfiles(filter: result);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: _buildCardArea(),
            ),
          ),
          _buildActionBar(),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        Text(
          'TABU',
          style: TextStyle(
            fontFamily:    TabuTypography.displayFont,
            fontSize:      24,
            fontWeight:    FontWeight.w900,
            color:         TabuColors.rosaPrincipal,
            letterSpacing: 5,
          ),
        ),
        const Spacer(),
        _TopIconBtn(icon: Icons.more_horiz_rounded, onTap: _showMoreSheet),
        const SizedBox(width: 8),
        _TopIconBtn(icon: Icons.tune_rounded, onTap: _openFilter),
      ]),
    );
  }

  Widget _buildCardArea() {
    if (_ctrl.isLoading) return _buildLoading();

    if (_ctrl.loadState == MatchLoadState.error) {
      return _buildError(_ctrl.error ?? 'Erro ao carregar perfis');
    }

    if (_ctrl.isEmpty || !_ctrl.hasMore) return _buildEmpty();

    final screenW = MediaQuery.of(context).size.width;

    if (_ctrl.isCurrentMyProfile) {
      return _buildMyOwnCard();
    }

    return AnimatedBuilder(
      animation: _exitCtrl,
      builder: (_, child) {
        final t  = _exitCtrl.value;
        final dx = screenW * _slideX * t;
        final dy = -20 * t;
        final op = (1.0 - t * 1.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(dx, dy),
          child:  Opacity(opacity: op, child: child),
        );
      },
      child: _ProfileCard(
        key:     ValueKey(_ctrl.index),
        profile: _ctrl.current!,
      ),
    );
  }

  Widget _buildMyOwnCard() {
    final profile = _ctrl.current!;
    return Stack(
      children: [
        _ProfileCard(
          key:     ValueKey('my_${_ctrl.index}'),
          profile: profile,
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: TabuColors.bg.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_rounded,
                    size: 15, color: TabuColors.rosaPrincipal),
                const SizedBox(width: 6),
                Text(
                  'Este é o seu perfil',
                  style: TextStyle(
                    fontFamily:    TabuTypography.bodyFont,
                    fontSize:      12,
                    fontWeight:    FontWeight.w600,
                    letterSpacing: 0.4,
                    color:         TabuColors.rosaPrincipal,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _skipMyCard,
                  child: Text(
                    'Pular →',
                    style: TextStyle(
                      fontFamily:    TabuTypography.bodyFont,
                      fontSize:      12,
                      fontWeight:    FontWeight.w700,
                      color:         TabuColors.textoMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(
            color:       TabuColors.rosaPrincipal,
            strokeWidth: 2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Buscando perfis...',
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize:   14,
            color:      TabuColors.textoMuted,
          ),
        ),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.explore_off_rounded, size: 60, color: TabuColors.border),
        const SizedBox(height: 16),
        Text(
          'Sem perfis por agora',
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize:   15,
            color:      TabuColors.textoMuted,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _loadProfiles(),
          child: Text(
            'Tente mudar os filtros',
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize:   13,
              color:      TabuColors.rosaPrincipal,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, size: 48, color: TabuColors.border),
        const SizedBox(height: 16),
        Text(
          'Algo deu errado',
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize:   15,
            color:      TabuColors.textoMuted,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _loadProfiles(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: TabuColors.rosaPrincipal, width: 0.8),
            ),
            child: Text(
              'TENTAR NOVAMENTE',
              style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      11,
                fontWeight:    FontWeight.w700,
                letterSpacing: 2,
                color:         TabuColors.rosaPrincipal,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildActionBar() {
    final isMe   = _ctrl.isCurrentMyProfile;
    final isBusy = _exitCtrl.isAnimating;

    final dislikeActive = const Color(0xFFE05A5A);
    final likeActive    = TabuColors.rosaPrincipal;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color:  TabuColors.bg,
        border: Border(top: BorderSide(color: TabuColors.borderMid, width: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionBtn(
            icon:    Icons.close_rounded,
            color:   isMe ? dislikeActive.withOpacity(0.30) : dislikeActive,
            // fundo adaptado ao tema claro: rosa-pálido avermelhado
            bgColor: TabuColors.errorPale,
            size:    60,
            onTap:   isBusy ? () {} : _onDislike,
          ),
          _ActionBtn(
            icon:    Icons.favorite_rounded,
            color:   isMe ? likeActive.withOpacity(0.30) : likeActive,
            // fundo adaptado ao tema claro: rosaPale do tema
            bgColor: TabuColors.rosaPale,
            size:    60,
            onTap:   isBusy ? () {} : _onLike,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PROFILE CARD  (scrollável)
// ════════════════════════════════════════════════════════════════════════════
class _ProfileCard extends StatefulWidget {
  const _ProfileCard({super.key, required this.profile});
  final MatchProfileModel profile;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late final ScrollController _scroll;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()
      ..addListener(() => setState(() => _scrollOffset = _scroll.offset));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  MatchProfileModel get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        color: TabuColors.bg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heroH = constraints.maxHeight;
            return SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHero(heroH),
                  _buildContent(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(double heroH) {
    const extra          = 70.0;
    final parallaxOffset = (_scrollOffset * 0.40).clamp(0.0, extra.toDouble());

    return SizedBox(
      height: heroH,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top:    -parallaxOffset,
            left:   0, right: 0,
            bottom: -(extra - parallaxOffset),
            child: p.avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: CloudinaryHelper.fullScreenUrl(p.avatarUrl),
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => _photoPlaceholder(),
                    errorWidget: (_, __, ___) => _photoPlaceholder(),
                  )
                : _photoPlaceholder(),
          ),

          // gradiente inferior — sempre sobre foto escura, mantém branco
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end:   Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.82),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // nome / orientação — sobre foto com gradiente escuro, mantém branco
          Positioned(
            left: 20, right: 20, bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily:    TabuTypography.displayFont,
                          fontSize:      34,
                          fontWeight:    FontWeight.w900,
                          color:         Colors.white,
                          letterSpacing: 0.2,
                          height:        1.1,
                          shadows: [
                            Shadow(
                              color:      Colors.black.withOpacity(0.5),
                              blurRadius: 8,
                              offset:     const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (p.orientationLabel.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          p.orientationLabel,
                          style: TextStyle(
                            fontFamily: TabuTypography.bodyFont,
                            fontSize:   15,
                            fontWeight: FontWeight.w400,
                            color:      Colors.white.withOpacity(0.75),
                            shadows: [
                              Shadow(
                                color:      Colors.black.withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  p.summaryLine,
                  style: TextStyle(
                    fontFamily: TabuTypography.bodyFont,
                    fontSize:   13,
                    fontWeight: FontWeight.w400,
                    color:      Colors.white.withOpacity(0.72),
                    shadows: [
                      Shadow(
                        color:      Colors.black.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
    color: TabuColors.bgCard,
    child: Center(
      child: Icon(
        Icons.person_outline_rounded,
        size:  72,
        color: TabuColors.border,
      ),
    ),
  );

  Widget _buildContent() {
    final hasBio = p.bio != null && p.bio!.isNotEmpty;

    return Container(
      color: TabuColors.bg,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _SectionLabel(text: 'INFORMAÇÕES'),
          const SizedBox(height: 14),

          _InfoTile(
            icon: Icons.location_on_outlined,
            text: [
              p.locationDisplay,
              if (p.distanceLabel.isNotEmpty) p.distanceLabel,
            ].where((s) => s.isNotEmpty).join('  ·  '),
          ),

          const SizedBox(height: 10),

          Wrap(spacing: 8, runSpacing: 8, children: [
            if (p.ageLabel.isNotEmpty)            _InfoChip(label: p.ageLabel),
            if (p.genderLabel.isNotEmpty)         _InfoChip(label: p.genderLabel),
            if (p.relationshipLabel.isNotEmpty)   _InfoChip(label: p.relationshipLabel),
            if (p.profileType == 'couple')        _InfoChip(label: 'Casal'),
          ]),

          if (hasBio) ...[
            const SizedBox(height: 28),
            _SectionDivider(),
            const SizedBox(height: 28),
            _SectionLabel(text: 'SOBRE MIM'),
            const SizedBox(height: 12),
            Text(
              p.bio!,
              style: TextStyle(
                fontFamily: TabuTypography.bodyFont,
                fontSize:   14,
                height:     1.70,
                color:      TabuColors.textoPrincipal.withOpacity(0.72),
              ),
            ),
          ],

          if (p.interests.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionDivider(),
            const SizedBox(height: 28),
            _SectionLabel(text: 'INTERESSES'),
            const SizedBox(height: 14),
            Wrap(
              spacing:    8,
              runSpacing: 8,
              children: p.interests
                  .map((tag) => _InterestChip(label: tag))
                  .toList(),
            ),
          ],

          if (p.profileType == 'couple' && p.partner != null) ...[
            const SizedBox(height: 28),
            _SectionDivider(),
            const SizedBox(height: 28),
            _SectionLabel(text: 'PARCEIRO(A)'),
            const SizedBox(height: 16),
            _PartnerCard(partner: p.partner!),
          ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MORE SHEET
// ════════════════════════════════════════════════════════════════════════════
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.profileName,
    required this.onReport,
    required this.onBlock,
  });

  final String       profileName;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        TabuColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: TabuColors.borderMid, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                color:        TabuColors.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              profileName,
              style: TextStyle(
                fontFamily:    TabuTypography.bodyFont,
                fontSize:      13,
                fontWeight:    FontWeight.w500,
                color:         TabuColors.textoMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Container(height: 0.6, color: TabuColors.borderMid),
          const SizedBox(height: 6),
          _SheetAction(
            icon:  Icons.flag_outlined,
            label: 'Reportar',
            color: const Color(0xFFE09A5A),
            onTap: onReport,
          ),
          _SheetAction(
            icon:  Icons.block_rounded,
            label: 'Bloquear',
            color: const Color(0xFFE05A5A),
            onTap: onBlock,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width:  double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color:        TabuColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: TabuColors.borderMid, width: 0.7),
                ),
                child: Center(
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: TabuTypography.bodyFont,
                      fontSize:   15,
                      fontWeight: FontWeight.w500,
                      color:      TabuColors.textoMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:          onTap,
      splashColor:    color.withOpacity(0.06),
      highlightColor: color.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
              border:       Border.all(color: color.withOpacity(0.25), width: 0.7),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontFamily: TabuTypography.bodyFont,
              fontSize:   15,
              fontWeight: FontWeight.w500,
              color:      color,
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SMALL WIDGETS
// ════════════════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 3, height: 14,
        decoration: BoxDecoration(
          color:        TabuColors.rosaPrincipal,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          fontFamily:    TabuTypography.bodyFont,
          fontSize:      11,
          fontWeight:    FontWeight.w800,
          letterSpacing: 2.5,
          color:         TabuColors.rosaPrincipal,
        ),
      ),
    ]);
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 0.6, color: TabuColors.borderMid.withOpacity(0.5));
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text});
  final IconData icon;
  final String   text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(children: [
      Icon(icon, size: 16, color: TabuColors.rosaPrincipal.withOpacity(0.8)),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          style: TextStyle(
            fontFamily: TabuTypography.bodyFont,
            fontSize:   13,
            color:      TabuColors.textoPrincipal.withOpacity(0.70),
            height:     1.4,
          ),
        ),
      ),
    ]);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        TabuColors.rosaPrincipal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border:       Border.all(
          color: TabuColors.rosaPrincipal.withOpacity(0.30), width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily:    TabuTypography.bodyFont,
          fontSize:      12,
          fontWeight:    FontWeight.w600,
          color:         TabuColors.textoSecundario,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  INTEREST CHIP
// ════════════════════════════════════════════════════════════════════════════
class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: TabuColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: TabuColors.borderMid,
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily:    TabuTypography.bodyFont,
          fontSize:      12,
          fontWeight:    FontWeight.w500,
          color:         TabuColors.textoPrincipal,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PARTNER CARD
// ════════════════════════════════════════════════════════════════════════════
class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner});
  final MatchPartnerModel partner;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = partner.avatarUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        TabuColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: TabuColors.borderMid, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56, height: 56,
              child: hasAvatar
                  ? CachedNetworkImage(
                      imageUrl: CloudinaryHelper.avatarUrl(partner.avatarUrl),
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => _avatarPlaceholder(),
                      errorWidget: (_, __, ___) => _avatarPlaceholder(),
                    )
                  : _avatarPlaceholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.name,
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily:    TabuTypography.displayFont,
                    fontSize:      16,
                    fontWeight:    FontWeight.w800,
                    color:         TabuColors.textoPrincipal,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing:    6,
                  runSpacing: 6,
                  children: [
                    if (partner.age != null)
                      _InfoChip(label: '${partner.age} anos'),
                    if (partner.genderLabel.isNotEmpty)
                      _InfoChip(label: partner.genderLabel),
                    if (partner.orientationLabel.isNotEmpty)
                      _InfoChip(label: partner.orientationLabel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
    color: TabuColors.bgCard,
    child: Center(
      child: Icon(
        Icons.person_outline_rounded,
        size:  28,
        color: TabuColors.border,
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.size,
    required this.onTap,
  });

  final IconData     icon;
  final Color        color;
  final Color        bgColor;
  final double       size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(size * 0.30),
          border:       Border.all(color: color.withOpacity(0.3), width: 0.8),
          boxShadow: [
            BoxShadow(
              color:      color.withOpacity(0.10),
              blurRadius: 14,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.44),
      ),
    );
  }
}

// ── Top icon buttons — adaptados ao tema claro ────────────────────────────
// Antes: fundo #181818 (escuro hardcoded) → preto feio sobre bg branco.
// Agora: bgCard (rosado claro) com borda borderMid vinho semitransparente
//        e ícone textoSecundario (vinho AA) — coerente com o resto da app.
class _TopIconBtn extends StatelessWidget {
  const _TopIconBtn({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color:        TabuColors.bgCard,
          borderRadius: BorderRadius.circular(11),
          border:       Border.all(color: TabuColors.borderMid, width: 0.8),
        ),
        child: Icon(icon, color: TabuColors.textoSecundario, size: 19),
      ),
    );
  }
}