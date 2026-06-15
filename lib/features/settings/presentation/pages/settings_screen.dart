import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/core/controllers/user_relationship_controller.dart';
import 'package:tclub/features/settings/presentation/pages/delete_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model simples de perfil
// ─────────────────────────────────────────────────────────────────────────────

class _UserProfile {
  final String uid;
  final String name;
  final String? avatar;
  final String? city;
  final String? state;

  _UserProfile({
    required this.uid,
    required this.name,
    this.avatar,
    this.city,
    this.state,
  });

  factory _UserProfile.fromMap(String uid, Map<dynamic, dynamic> map) {
    return _UserProfile(
      uid: uid,
      name: map['name'] as String? ?? 'Usuário',
      avatar: map['avatar'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
    );
  }

  String get location {
    if (city != null && state != null) return '$city, $state';
    if (city != null) return city!;
    if (state != null) return state!;
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  final String name;
  final String myUserId;

  const SettingsScreen({
    super.key,
    required this.name,
    required this.myUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TClubColors.bg,
      appBar: AppBar(
        title: const Text('CONFIGURAÇÕES'),
        backgroundColor: TClubColors.nav,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: TClubColors.fundoApp),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, 'SEGURANÇA'),
              const SizedBox(height: 16),
              _buildCard(
                child: _buildSettingsTile(
                  context: context,
                  icon: Icons.block_outlined,
                  title: 'USUÁRIOS BLOQUEADOS',
                  subtitle: 'Gerenciar usuários bloqueados',
                  onTap: () => _showBlockedUsersSheet(context),
                ),
              ),
              const SizedBox(height: 28),
              _buildSectionTitle(context, 'ZONA DE PERIGO'),
              const SizedBox(height: 16),
              _buildCard(
                child: _buildSettingsTile(
                  context: context,
                  icon: Icons.delete_outline,
                  title: 'DELETAR CONTA',
                  subtitle: 'Remover permanentemente sua conta',
                  onTap: () => _showDeleteAccountDialog(context),
                  isDanger: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: TClubColors.redClaro,
            letterSpacing: 1.5,
          ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: TClubColors.bgCard,
        border: Border.all(color: TClubColors.border, width: 0.8),
      ),
      child: child,
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool isDanger = false,
  }) {
    final Color iconColor = isDanger
        ? TClubColors.redPrincipal.withOpacity(0.85)
        : TClubColors.redClaro;
    final Color titleColor = isDanger
        ? TClubColors.redPrincipal.withOpacity(0.85)
        : TClubColors.textoPrincipal;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TClubColors.bgAlt,
                border: Border.all(color: TClubColors.border, width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: titleColor),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right, color: TClubColors.subtle, size: 20),
          ],
        ),
      ),
    );
  }

  void _showBlockedUsersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BlockedUsersSheet(myUserId: myUserId),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: TClubColors.bgCard,
            border: Border.all(color: TClubColors.border, width: 0.8),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.delete_outline,
                color: TClubColors.redPrincipal.withOpacity(0.8),
                size: 28,
              ),
              const SizedBox(height: 20),
              Text('DELETAR CONTA',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Esta ação é irreversível. Todos os seus dados serão permanentemente removidos.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: TClubColors.border, width: 1),
                      ),
                      child: const Text('CANCELAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ImprovedDeleteAccountSheet(userName: name),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor:
                            TClubColors.redPrincipal.withOpacity(0.15),
                        foregroundColor:
                            TClubColors.redPrincipal.withOpacity(0.9),
                        elevation: 0,
                        side: BorderSide(
                          color: TClubColors.redPrincipal.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: const Text('DELETAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet de bloqueados
// ─────────────────────────────────────────────────────────────────────────────

class _BlockedUsersSheet extends StatefulWidget {
  final String myUserId;

  const _BlockedUsersSheet({required this.myUserId});

  @override
  State<_BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends State<_BlockedUsersSheet> {
  final _controller = UserRelationShipController();
  final _db = FirebaseDatabase.instance.ref();

  List<_UserProfile> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final ids = await _controller.fetchAllBlockedUsers(widget.myUserId);

    // Busca perfis em paralelo
    final profiles = await Future.wait(
      ids.map((uid) => _fetchProfile(uid)),
    );

    if (mounted) {
      setState(() {
        _profiles = profiles.whereType<_UserProfile>().toList();
        _isLoading = false;
      });
    }
  }

  Future<_UserProfile?> _fetchProfile(String uid) async {
    try {
      final snap = await _db.child('Users/$uid').get();
      if (!snap.exists || snap.value == null) return null;
      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      return _UserProfile.fromMap(uid, map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _unblock(_UserProfile profile) async {
    final ok = await _controller.unblockUser(widget.myUserId, profile.uid);
    if (!mounted) return;

    if (ok) {
      setState(() => _profiles.removeWhere((p) => p.uid == profile.uid));
      _showSnackbar('${profile.name} foi desbloqueado.', success: true);
    } else {
      _showSnackbar('Erro ao desbloquear. Tente novamente.', success: false);
    }
  }

  void _showSnackbar(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: TClubColors.textoPrincipal,
              ),
        ),
        backgroundColor: TClubColors.bgCard,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: success
                ? TClubColors.redClaro.withOpacity(0.4)
                : TClubColors.redPrincipal.withOpacity(0.5),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        gradient: TClubColors.fundoApp,
        border: const Border(
          top: BorderSide(color: TClubColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 3, color: TClubColors.subtle),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TClubColors.bgAlt,
                    border: Border.all(color: TClubColors.border, width: 1),
                  ),
                  child: const Icon(Icons.block,
                      color: TClubColors.redClaro, size: 22),
                ),
                const SizedBox(width: 16),
                Text(
                  'USUÁRIOS BLOQUEADOS',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: TClubColors.redClaro,
        ),
      );
    }

    if (_profiles.isEmpty) {
      return Center(
        child: Text(
          'Nenhum usuário bloqueado.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _profiles.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: TClubColors.border),
      itemBuilder: (context, index) => _buildProfileTile(_profiles[index]),
    );
  }

  Widget _buildProfileTile(_UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: TClubColors.bgCard,
              border: Border.all(color: TClubColors.border, width: 1),
            ),
            child: profile.avatar != null
                ? CachedNetworkImage(
                    imageUrl: profile.avatar!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: TClubColors.subtle,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.person,
                      color: TClubColors.subtle,
                      size: 26,
                    ),
                  )
                : const Icon(Icons.person, color: TClubColors.subtle, size: 26),
          ),

          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: TClubColors.textoPrincipal,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 11, color: TClubColors.subtle),
                      const SizedBox(width: 3),
                      Text(
                        profile.location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: TClubColors.subtle,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Botão
          OutlinedButton(
            onPressed: () => _unblock(profile),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: BorderSide(color: TClubColors.border, width: 1),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'DESBLOQUEAR',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: TClubColors.redClaro,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

