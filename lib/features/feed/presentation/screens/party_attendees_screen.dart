// lib/features/feed/presentation/screens/party_attendees_screen.dart
//
// Tela admin: lista INTERESSADOS e CONFIRMADOS com paginação cursor-based.
//
// Estratégia de leitura (custo mínimo):
//   • Busca Festas/{festaId}/presenca inteiro UMA VEZ por página (orderByKey + cursor).
//   • Filtra o valor ('interessado' | 'confirmado') no cliente — o nó presenca
//     tem poucos registros por fetch (limitToFirst PAGE_SIZE).
//   • Perfis: Future.wait nos UIDs da página (2 campos cada: name + avatar).
//   • Totais: campos já existentes em PartyModel (zero leitura extra).

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/party/data/models/party_model.dart';

class PartyAttendeesScreen extends StatefulWidget {
  final PartyModel festa;
  const PartyAttendeesScreen({super.key, required this.festa});

  @override
  State<PartyAttendeesScreen> createState() => _PartyAttendeesScreenState();
}

class _PartyAttendeesScreenState extends State<PartyAttendeesScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 20;

  late final TabController _tab;
  final _db = FirebaseDatabase.instance;

  final _items     = <String, List<_AttendeeItem>>{'interessado': [], 'confirmado': []};
  final _loading   = <String, bool>{'interessado': false, 'confirmado': false};
  final _hasMore   = <String, bool>{'interessado': true, 'confirmado': true};
  final _lastKey   = <String, String?>{'interessado': null, 'confirmado': null};
  final _inited    = <String, bool>{'interessado': false, 'confirmado': false};

  String get _curTab => _tab.index == 0 ? 'interessado' : 'confirmado';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging && !(_inited[_curTab] ?? false)) {
        _loadPage(_curTab);
      }
    });
    _loadPage('interessado');
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadPage(String tipo) async {
    if (_loading[tipo] == true || _hasMore[tipo] == false) return;
    setState(() => _loading[tipo] = true);

    try {
      final ref = _db.ref('Festas/${widget.festa.id}/presenca');

      // Cursor por chave (uid): não precisa de índice, filtra valor no cliente
      Query query = _lastKey[tipo] == null
          ? ref.orderByKey().limitToFirst(_pageSize)
          : ref.orderByKey().startAfter(_lastKey[tipo]!).limitToFirst(_pageSize);

      final snap = await query.get();

      if (!snap.exists || snap.value == null) {
        if (mounted) setState(() {
          _hasMore[tipo] = false;
          _loading[tipo] = false;
          _inited[tipo]  = true;
        });
        return;
      }

      final raw = Map<String, dynamic>.from(snap.value as Map);

      // Filtra pelo tipo correto no cliente
      final uids = raw.entries
          .where((e) => e.value == tipo)
          .map((e) => e.key as String)
          .toList();

      // Última chave da página (não do filtro) para cursor correto
      final lastKeyInPage = raw.keys.last;
      final isLastPage = raw.length < _pageSize;

      // Busca perfis em batch
      final profiles = uids.isEmpty
          ? <_AttendeeItem>[]
          : (await Future.wait(uids.map(_fetchProfile)))
              .whereType<_AttendeeItem>()
              .toList();

      if (!mounted) return;
      setState(() {
        _items[tipo]!.addAll(profiles);
        _lastKey[tipo] = lastKeyInPage;
        _hasMore[tipo] = !isLastPage;
        _loading[tipo] = false;
        _inited[tipo]  = true;
      });
    } catch (e) {
      debugPrint('[PartyAttendees] $tipo: $e');
      if (mounted) setState(() { _loading[tipo] = false; _inited[tipo] = true; });
    }
  }

  Future<_AttendeeItem?> _fetchProfile(String uid) async {
    try {
      final res = await Future.wait([
        _db.ref('UsersPublic/$uid/name').get(),
        _db.ref('UsersPublic/$uid/avatar').get(),
      ]);
      return _AttendeeItem(
        uid:    uid,
        name:   res[0].value as String? ?? 'Usuário',
        avatar: res[1].value as String?,
      );
    } catch (_) {
      return _AttendeeItem(uid: uid, name: 'Usuário', avatar: null);
    }
  }

  Future<void> _refresh(String tipo) async {
    setState(() {
      _items[tipo]!.clear();
      _lastKey[tipo] = null;
      _hasMore[tipo] = true;
      _inited[tipo]  = false;
    });
    await _loadPage(tipo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TClubColors.bg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _AttendeeList(
                items:       _items['interessado']!,
                loading:     _loading['interessado'] ?? false,
                hasMore:     _hasMore['interessado'] ?? false,
                inited:      _inited['interessado']  ?? false,
                onLoadMore:  () => _loadPage('interessado'),
                onRefresh:   () => _refresh('interessado'),
                emptyLabel:  'NINGUÉM INTERESSADO AINDA',
                emptyIcon:   Icons.star_border_rounded,
                accentColor: TClubColors.redClaro,
              ),
              _AttendeeList(
                items:       _items['confirmado']!,
                loading:     _loading['confirmado'] ?? false,
                hasMore:     _hasMore['confirmado'] ?? false,
                inited:      _inited['confirmado']  ?? false,
                onLoadMore:  () => _loadPage('confirmado'),
                onRefresh:   () => _refresh('confirmado'),
                emptyLabel:  'NINGUÉM CONFIRMADO AINDA',
                emptyIcon:   Icons.check_circle_outline_rounded,
                accentColor: const Color(0xFF4ECDC4),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: TClubColors.bg,
        border: Border(bottom: BorderSide(color: TClubColors.border, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: TClubColors.redPrincipal, size: 18),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    widget.festa.nome.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: TClubTypography.displayFont,
                      fontSize: 16, letterSpacing: 2,
                      color: TClubColors.textoPrincipal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text('PARTICIPANTES', style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 3, color: TClubColors.redPrincipal,
                  )),
                ]),
              ),
            ]),
          ),

          // TabBar — texto compacto para não transbordar
          TabBar(
            controller: _tab,
            indicatorColor: TClubColors.redPrincipal,
            indicatorWeight: 1.5,
            labelColor: TClubColors.redPrincipal,
            unselectedLabelColor: TClubColors.subtle,
            labelPadding: EdgeInsets.zero,
            tabs: [
              _CompactTab(
                icon:  Icons.star_rounded,
                label: 'INTERESSADOS',
                count: widget.festa.interessados,
                active: _tab.index == 0,
              ),
              _CompactTab(
                icon:  Icons.check_circle_rounded,
                label: 'CONFIRMADOS',
                count: widget.festa.confirmados,
                active: _tab.index == 1,
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Tab compacto sem overflow ──────────────────────────────────────────────────
class _CompactTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  const _CompactTab({
    required this.icon, required this.label,
    required this.count, required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? TClubColors.redPrincipal : TClubColors.subtle;
    return SizedBox(
      height: 44,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.5, color: color,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                border: Border.all(color: color.withOpacity(0.3), width: 0.7),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 9, fontWeight: FontWeight.w700, color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LISTA COM PAGINAÇÃO + PULL-TO-REFRESH
// ══════════════════════════════════════════════════════════════════════════════
class _AttendeeList extends StatelessWidget {
  final List<_AttendeeItem> items;
  final bool loading, hasMore, inited;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final String emptyLabel;
  final IconData emptyIcon;
  final Color accentColor;

  const _AttendeeList({
    required this.items, required this.loading, required this.hasMore,
    required this.inited, required this.onLoadMore, required this.onRefresh,
    required this.emptyLabel, required this.emptyIcon, required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Carregando primeira página
    if (!inited && loading) {
      return const Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 1.5,
              color: TClubColors.redPrincipal)));
    }

    // Vazio
    if (inited && items.isEmpty) {
      return RefreshIndicator(
        color: TClubColors.redPrincipal,
        backgroundColor: TClubColors.bgAlt,
        onRefresh: onRefresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          SizedBox(height: 300, child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 56, height: 56,
                decoration: BoxDecoration(color: TClubColors.bgCard,
                    border: Border.all(color: TClubColors.border, width: 0.8)),
                child: Icon(emptyIcon, color: TClubColors.border, size: 24)),
              const SizedBox(height: 16),
              Text(emptyLabel, style: const TextStyle(
                fontFamily: TClubTypography.bodyFont, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 3, color: TClubColors.subtle,
              )),
            ],
          )),
        ]),
      );
    }

    return RefreshIndicator(
      color: TClubColors.redPrincipal,
      backgroundColor: TClubColors.bgAlt,
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification &&
              n.metrics.extentAfter < 200 && hasMore && !loading) {
            onLoadMore();
          }
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          itemCount: items.length + (hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == items.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: loading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 1.5,
                            color: TClubColors.redPrincipal))
                    : GestureDetector(
                        onTap: onLoadMore,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: TClubColors.redPrincipal.withOpacity(0.4),
                                width: 0.8)),
                          child: const Text('CARREGAR MAIS', style: TextStyle(
                            fontFamily: TClubTypography.bodyFont, fontSize: 9,
                            fontWeight: FontWeight.w700, letterSpacing: 2.5,
                            color: TClubColors.redPrincipal,
                          )),
                        ),
                      )),
              );
            }
            return _AttendeeTile(item: items[i], accentColor: accentColor);
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TILE
// ══════════════════════════════════════════════════════════════════════════════
class _AttendeeTile extends StatelessWidget {
  final _AttendeeItem item;
  final Color accentColor;
  const _AttendeeTile({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(
          color: TClubColors.border.withOpacity(0.4), width: 0.5))),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: accentColor.withOpacity(0.3), width: 0.8)),
          child: item.avatar != null && item.avatar!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: CloudinaryHelper.avatarUrl(item.avatar!),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => _fallback(),
                  errorWidget: (_, __, ___) => _fallback())
              : _fallback(),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(item.name.toUpperCase(), style: const TextStyle(
          fontFamily: TClubTypography.bodyFont, fontSize: 13,
          fontWeight: FontWeight.w600, letterSpacing: 1.2,
          color: TClubColors.textoPrincipal,
        ), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _fallback() {
    final initial = item.name.isNotEmpty ? item.name[0].toUpperCase() : '?';
    return Container(color: TClubColors.bgCard, child: Center(child: Text(initial,
        style: TextStyle(fontFamily: TClubTypography.displayFont,
            fontSize: 18, color: accentColor))));
  }
}

class _AttendeeItem {
  final String uid, name;
  final String? avatar;
  const _AttendeeItem({required this.uid, required this.name, required this.avatar});
}

