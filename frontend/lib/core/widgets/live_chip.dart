import 'package:flutter/material.dart';

import '../theme.dart';

/// La chapita de "en vivo".
///
/// Esta porque, cuando el tiempo real NO anda, no hay ninguna senal visible:
/// la pantalla se queda quieta y uno cree que no paso nada. Con la chapita se
/// ve de un vistazo si el WebSocket esta conectado.
///
/// Si no aparece, la pantalla sigue siendo usable: se actualiza con el boton de
/// actualizar o deslizando hacia abajo. Por eso es una chapita discreta y no un
/// cartel de error.
///
/// Vive aca y no dentro de una pantalla porque la usan dos: el seguimiento del
/// cliente y los pedidos del restaurante.
class LiveChip extends StatelessWidget {
  const LiveChip({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.mint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'En vivo',
            style: text.labelSmall?.copyWith(
              color: AppTheme.tealDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
