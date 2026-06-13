// lib/features/user/moderation/moderation.dart
//
//  Barrel de exports da feature user/moderation.
//  Importe apenas este arquivo para usar qualquer parte da feature.
//
//  Exemplo:
//    import 'package:tabuapp/features/user/moderation/moderation.dart';
//
//    // Abrir tela de denúncia de post:
//    await ReportPage.push(context,
//      config: ReportPageConfig.post(
//        postId:      post.id,
//        postOwnerId: post.ownerId,
//        postTitulo:  post.titulo,
//      ),
//    );

// ── Data ──────────────────────────────────────────────────────────────────────
export 'data/models/report_models.dart';
export 'data/models/report_motives.dart';
export 'data/repositories/report_repository.dart';

// ── Controller ────────────────────────────────────────────────────────────────
export 'controller/report_controller.dart';

// ── Presentation ──────────────────────────────────────────────────────────────
export 'presentation/pages/report_page.dart';
export 'presentation/widgets/report_shared_widgets.dart';