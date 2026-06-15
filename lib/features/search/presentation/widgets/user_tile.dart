// lib/features/search/presentation/widgets/user_tile.dart

import 'package:flutter/material.dart';
import 'package:tclub/features/search/domain/entities/user_search.dart';

/// Card de perfil no formato grid: foto circular, ícones de gênero,
/// nome, distância e bairro/localização.
class UserTile extends StatelessWidget {
  final UserSearchEntity user;
  final VoidCallback? onTap;
  final double? distanceKm;

  const UserTile({
    super.key,
    required this.user,
    this.onTap,
    this.distanceKm,
  });

  /// Retorna os ícones de gênero baseados no profileType e genderIdentity.
  List<Widget> _buildGenderIcons() {
    final icons = <Widget>[];

    Color _colorFor(String gender) {
      switch (gender.toLowerCase()) {
        case 'homem':
        case 'male':
          return Colors.blue;
        case 'mulher':
        case 'female':
          return Colors.pinkAccent;
        default:
          return Colors.purple;
      }
    }

    IconData _iconFor(String gender) {
      switch (gender.toLowerCase()) {
        case 'homem':
        case 'male':
          return Icons.male;
        case 'mulher':
        case 'female':
          return Icons.female;
        default:
          return Icons.transgender;
      }
    }

    if (user.profileType == 'couple') {
      // Casal: mostra dois ícones
      icons.add(Icon(Icons.male, size: 14, color: Colors.blue));
      icons.add(Icon(Icons.female, size: 14, color: Colors.pinkAccent));
    } else if (user.genderIdentity.isNotEmpty) {
      icons.add(Icon(
        _iconFor(user.genderIdentity),
        size: 14,
        color: _colorFor(user.genderIdentity),
      ));
    }

    return icons;
  }

  /// Retorna a localização mais específica disponível (bairro > cidade).
  String get _locationLabel {
    if (user.neighborhood.isNotEmpty) return user.neighborhood;
    if (user.city.isNotEmpty) return user.city;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Foto circular ──
          CircleAvatar(
            radius: 45,
            backgroundColor: Colors.grey.shade300,
            backgroundImage:
                user.avatar.isNotEmpty ? NetworkImage(user.avatar) : null,
            child: user.avatar.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 6),

          // ── Ícones de gênero + Nome ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._buildGenderIcons(),
              if (_buildGenderIcons().isNotEmpty) const SizedBox(width: 2),
              Flexible(
                child: Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),

          // ── Distância ──
          if (distanceKm != null) ...[
            const SizedBox(height: 2),
            Text(
              '${distanceKm!.toStringAsFixed(1)} km',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          // ── Bairro / Localização ──
          if (_locationLabel.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              _locationLabel,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

