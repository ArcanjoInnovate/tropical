// lib/features/search/presentation/widgets/party_tile.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tclub/core/helpers/cloudinary_helper.dart';
import 'package:tclub/features/search/domain/entities/party_search.dart';
import 'package:cached_network_image/cached_network_image.dart';


class PartyTile extends StatelessWidget {
  final PartySearchEntity party;
  final VoidCallback? onTap;

  /// Distância em km para exibir (opcional, apenas no modo proximidade).
  final double? distanceKm;

  const PartyTile({
    super.key,
    required this.party,
    this.onTap,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner ou ícone padrão
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: party.hasBanner
                      ? CachedNetworkImage(
                          imageUrl: CloudinaryHelper.bannerUrl(party.bannerUrl!),
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => const _DefaultPartyIcon(),
                          errorWidget: (_, __, ___) =>
                              const _DefaultPartyIcon(),
                        )
                      : const _DefaultPartyIcon(),
                ),
              ),
              const SizedBox(width: 12),

              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (party.hasLocal)
                      Text(
                        party.formattedLocation,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(party.dataInicio),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _CountChip(
                          icon: Icons.star_border,
                          count: party.interessados,
                          label: 'interesse',
                        ),
                        const SizedBox(width: 8),
                        _CountChip(
                          icon: Icons.check_circle_outline,
                          count: party.confirmados,
                          label: 'confirmados',
                        ),
                        if (distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              const Icon(Icons.near_me, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${distanceKm!.toStringAsFixed(1)} km',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ],
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

class _DefaultPartyIcon extends StatelessWidget {
  const _DefaultPartyIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.celebration, size: 32, color: Colors.grey),
    );
  }
}

class _CountChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _CountChip({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12),
        const SizedBox(width: 2),
        Text('$count', style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

