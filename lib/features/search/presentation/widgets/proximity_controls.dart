// lib/features/search/presentation/widgets/proximity_controls.dart

import 'package:flutter/material.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';

/// Widget de controles de busca por proximidade.
///
/// Responsabilidade: Exibir o slider de raio e o botão de ativar GPS.
/// Notifica o pai via callbacks — não conhece BLoC ou serviço de localização.
class ProximityControls extends StatelessWidget {
  /// Raio atual em km.
  final double radiusKm;

  /// Raio mínimo permitido.
  final double minRadius;

  /// Raio máximo permitido.
  final double maxRadius;

  /// True se o modo proximidade está ativo.
  final bool isActive;

  /// True enquanto a localização está sendo obtida.
  final bool isLocating;

  /// Callback ao mover o slider (retorna novo raio).
  final ValueChanged<double> onRadiusChanged;

  /// Callback ao pressionar o botão de ativar localização.
  final VoidCallback onActivate;

  /// Callback ao pressionar o botão de desativar.
  final VoidCallback onDeactivate;

  const ProximityControls({
    super.key,
    required this.radiusKm,
    required this.onRadiusChanged,
    required this.onActivate,
    required this.onDeactivate,
    this.minRadius = 1.0,
    this.maxRadius = 100.0,
    this.isActive = false,
    this.isLocating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botão de ativar/desativar
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? TabuColors.rosaPrincipal : TabuColors.rosaDeep,
                  foregroundColor: TabuColors.branco,
                ),
                onPressed: isLocating
                    ? null
                    : isActive
                        ? onDeactivate
                        : onActivate,
                icon: isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isActive ? Icons.gps_off : Icons.my_location),
                label: Text(
                  style: const TextStyle(fontWeight: FontWeight.w600, color: TabuColors.branco),
                  isLocating
                      ? 'Obtendo localização...'
                      : isActive
                          ? 'Desativar proximidade'
                          : 'Buscar perto de mim',
                ),
              ),
            ),
          ],
        ),

        // Slider de raio (visível apenas quando ativo)
        if (isActive) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.radar, size: 16),
              const SizedBox(width: 6),
              Text(
                'Raio: ${radiusKm.toStringAsFixed(0)} km',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Slider(
            value: radiusKm.clamp(minRadius, maxRadius),
            min: minRadius,
            max: maxRadius,
            divisions: ((maxRadius - minRadius) / 5).round(),
            label: '${radiusKm.toStringAsFixed(0)} km',
            onChanged: onRadiusChanged,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${minRadius.toStringAsFixed(0)} km',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                '${maxRadius.toStringAsFixed(0)} km',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }
}