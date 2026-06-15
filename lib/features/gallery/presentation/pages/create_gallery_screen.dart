// lib/screens/screens_home/home_screen/posts/create_gallery_screen.dart
//
// NOVO: seletor de capa para vídeos da galeria.
//   • Vídeos têm botão "ESCOLHER CAPA" igual ao create_post_screen.
//   • A capa é salva em gallery/{uid}/covers/{timestamp}.jpg no Storage.
//   • O campo cover_url é persistido em Gallery/{uid}/items/{itemId}.
//   • A capa aparece como thumbnail no grid do perfil e no feed da galeria.
//
// FIX: preview e captura do FramePickerSheet agora usam AspectRatio(1.0) +
//   BoxFit.cover para garantir crop quadrado centralizado, igual ao card do
//   grid (crossAxisCount: 3, mainAxisExtent: 120, childAspectRatio: 1.0).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:tclub/core/helpers/media_permission_helper.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/post/data/services/cloudinary_service.dart';
import 'package:tclub/core/services/media/videos_trim_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  TELA PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════
class CreateGalleryItemScreen extends StatefulWidget {
  const CreateGalleryItemScreen({super.key, required this.userData});
  final Map<String, dynamic> userData;

  @override
  State<CreateGalleryItemScreen> createState() =>
      _CreateGalleryItemScreenState();
}

enum _Step {
  idle,
  processandoVideo,
  uploadingMedia,
  uploadingCover,
  salvando,
  concluido,
  erro,
}

class _CreateGalleryItemScreenState extends State<CreateGalleryItemScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late final TabController _tabCtrl;

  // ── Foto ───────────────────────────────────────────────────────────────────
  File? _foto;

  // ── Vídeo ──────────────────────────────────────────────────────────────────
  int _videoSessionId = 0;
  File? _video;
  VideoPlayerController? _videoCtrl;
  Duration? _videoDuration;
  bool _videoPlaying = false;

  // ── Capa personalizada (apenas vídeos) ─────────────────────────────────────
  Uint8List? _coverBytes;
  File? _coverFile;
  bool _capaPersonalizada = false;

  // ── Estado de publicação ───────────────────────────────────────────────────
  _Step _step = _Step.idle;
  double _uploadProgress = 0.0;

  bool get _busy =>
      _step != _Step.idle &&
      _step != _Step.concluido &&
      _step != _Step.erro;

  bool get _podePublicar {
    if (_busy) return false;
    if (_tabCtrl.index == 0) return _foto != null;
    if (_tabCtrl.index == 1) return _video != null;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _videoCtrl?.dispose();
    _coverFile?.deleteSync(recursive: false);
    super.dispose();
  }

  // ── Foto ───────────────────────────────────────────────────────────────────
  Future<void> _pickFoto(ImageSource src) async {
    Navigator.pop(context);
    if (!await requestMediaPermission(context, src)) return;
    final p = await _picker.pickImage(
        source: src, maxWidth: 1920, maxHeight: 1920, imageQuality: 90);
    if (p == null) return;
    setState(() => _foto = File(p.path));
  }

  // ── Vídeo ──────────────────────────────────────────────────────────────────
  Future<void> _pickVideo(ImageSource src) async {
    Navigator.pop(context);
    if (!await requestMediaPermission(context, src)) return;
    final p = await _picker.pickVideo(source: src);
    if (p == null) return;
    await _carregarVideo(File(p.path));
  }

  Future<void> _carregarVideo(File file) async {
    await _videoCtrl?.dispose();
    final int sess = ++_videoSessionId;

    setState(() {
      _video = null;
      _coverBytes = null;
      _coverFile = null;
      _capaPersonalizada = false;
      _videoPlaying = false;
      _videoCtrl = null;
      _step = _Step.processandoVideo;
    });

    File processado;
    try {
      processado = await VideoTrimService.trimAndCompress(
        file: file,
        maxSeconds: 10, // galeria: máximo 10 segundos
      );
      if (!mounted || _videoSessionId != sess) {
        try { processado.deleteSync(); } catch (_) {}
        return;
      }
    } catch (_) {
      processado = file;
    }

    final playerCtrl = VideoPlayerController.file(processado);
    await playerCtrl.initialize();
    playerCtrl.addListener(() {
      if (mounted) setState(() => _videoPlaying = playerCtrl.value.isPlaying);
    });

    if (!mounted || _videoSessionId != sess) {
      playerCtrl.dispose();
      return;
    }

    setState(() {
      _video = processado;
      _videoCtrl = playerCtrl;
      _videoDuration = playerCtrl.value.duration;
      _step = _Step.idle;
    });

    _gerarThumbPrimeiroFrame(processado, sess);
  }

  Future<void> _gerarThumbPrimeiroFrame(File videoFile, int sess) async {
    try {
      final tmp  = await getTemporaryDirectory();
      final path = '${tmp.path}/gcov_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Gera thumbnail 1:1 (crop centralizado) para cobrir exatamente o card do grid.
      // vf "crop=min(iw\,ih):min(iw\,ih),scale=480:480" → recorta quadrado central e escala.
      final session = await FFmpegKit.execute(
        '-y -i "${videoFile.path}" '
        '-vframes 1 '
        '-vf "crop=min(iw\\,ih):min(iw\\,ih),scale=480:480" '
        '-q:v 2 "$path"',
      );
      if (!ReturnCode.isSuccess(await session.getReturnCode())) return;

      final f = File(path);
      if (!f.existsSync()) return;
      final bytes = await f.readAsBytes();
      f.deleteSync();

      if (!mounted || _videoSessionId != sess || _capaPersonalizada) return;
      await _aplicarCoverBytes(bytes, sess: sess);
    } catch (_) {}
  }

  Future<void> _aplicarCoverBytes(Uint8List bytes, {required int sess}) async {
    final tmp = await getTemporaryDirectory();
    final path = '${tmp.path}/gcov_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = await File(path).writeAsBytes(bytes);
    if (!mounted) { file.deleteSync(); return; }
    if (_videoSessionId != sess) { file.deleteSync(); return; }

    final old = _coverFile;
    setState(() {
      _coverBytes = bytes;
      _coverFile = file;
    });
    if (old != null && old.path != file.path) {
      old.deleteSync(recursive: false);
    }
  }

  void _toggleVideoPlay() {
    if (_videoCtrl == null) return;
    if (_videoCtrl!.value.isPlaying) {
      _videoCtrl!.pause();
    } else {
      if (_videoCtrl!.value.position >= _videoCtrl!.value.duration) {
        _videoCtrl!.seekTo(Duration.zero);
      }
      _videoCtrl!.play();
    }
    HapticFeedback.selectionClick();
  }

  void _removerVideo() {
    _videoCtrl?.dispose();
    _coverFile?.deleteSync(recursive: false);
    _videoSessionId++;
    setState(() {
      _video = null;
      _coverBytes = null;
      _coverFile = null;
      _videoCtrl = null;
      _videoDuration = null;
      _videoPlaying = false;
      _capaPersonalizada = false;
    });
  }

  // ── Seletor de capa ────────────────────────────────────────────────────────
  void _abrirSeletorCapa() {
    if (_video == null || _videoCtrl == null || !_videoCtrl!.value.isInitialized) return;
    _videoCtrl!.pause();
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => _FramePickerSheet(
        videoCtrl: _videoCtrl!,
        totalDuration: _videoDuration!,
        currentCover: _coverBytes,
        onConfirm: (Uint8List bytes) async {
          _capaPersonalizada = true;
          final sess = _videoSessionId;
          await _aplicarCoverBytes(bytes, sess: sess);
          if (mounted && _videoSessionId == sess) {
            setState(() => _capaPersonalizada = true);
            HapticFeedback.mediumImpact();
            _snack('Capa definida! 🎬', success: true);
          }
        },
      ),
    );
  }

  // ── Publicar ───────────────────────────────────────────────────────────────
  Future<void> _publicar() async {
    if (!_podePublicar) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) { _snack('Usuário não autenticado.'); return; }

    setState(() { _step = _Step.uploadingMedia; _uploadProgress = 0.0; });

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      String mediaUrl;
      String? thumbUrl;
      String? coverUrl;
      int? videoDurationSec;
      String type;

      if (_tabCtrl.index == 0 && _foto != null) {
        // ── FOTO ──────────────────────────────────────────────────────────────
        type = 'foto';
        final url = await CloudinaryService.instance.uploadFile(
          file: _foto!,
          resourceType: CloudinaryResourceType.image,
          folder: 'gallery/$uid',
          publicId: '$ts',
          onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
        );
        if (url == null) throw Exception('Upload da foto falhou.');
        mediaUrl = url;

      } else if (_tabCtrl.index == 1 && _video != null) {
        // ── VÍDEO ─────────────────────────────────────────────────────────────
        type = 'video';
        videoDurationSec = _videoDuration?.inSeconds;

        // 1. Upload do vídeo
        final vUrl = await CloudinaryService.instance.uploadFile(
          file: _video!,
          resourceType: CloudinaryResourceType.video,
          folder: 'gallery/$uid/videos',
          publicId: '$ts',
          onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
        );
        if (vUrl == null) throw Exception('Upload do vídeo falhou.');
        mediaUrl = vUrl;

        // 2. Thumbnail auto-gerada (primeiro frame, já cropada 1:1 via FFmpeg)
        if (_coverBytes != null && !_capaPersonalizada) {
          setState(() { _step = _Step.uploadingCover; _uploadProgress = 0.0; });
          final tUrl = await CloudinaryService.instance.uploadBytes(
            bytes: _coverBytes!,
            filename: 'thumb_$ts.jpg',
            resourceType: CloudinaryResourceType.image,
            folder: 'gallery/$uid/thumbs',
            publicId: '$ts',
            onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
          );
          thumbUrl = tUrl;
        }

        // 3. Capa personalizada (frame escolhido pelo usuário, cropado 1:1)
        if (_capaPersonalizada && _coverBytes != null) {
          setState(() { _step = _Step.uploadingCover; _uploadProgress = 0.0; });
          final cUrl = await CloudinaryService.instance.uploadBytes(
            bytes: _coverBytes!,
            filename: 'cover_$ts.jpg',
            resourceType: CloudinaryResourceType.image,
            folder: 'gallery/$uid/covers',
            publicId: '$ts',
            onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
          );
          coverUrl = cUrl;
          // thumb também usa a capa personalizada
          thumbUrl ??= cUrl;
        }

      } else {
        return;
      }

      // ── Salva no Firebase ──────────────────────────────────────────────────
      if (!mounted) return;
      setState(() => _step = _Step.salvando);

      final db = FirebaseDatabase.instance;
      final itemRef = db.ref('Gallery/$uid/items').push();

      final payload = <String, dynamic>{
        'user_id':    uid,
        'type':       type,
        'media_url':  mediaUrl,
        if (thumbUrl != null) 'thumb_url': thumbUrl,
        if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
        if (videoDurationSec != null) 'video_duration': videoDurationSec,
        'created_at': ServerValue.timestamp,
      };

      await itemRef.set(payload);

      // Garante que o nó raiz da galeria existe
      await db.ref('Gallery/$uid/created').set(true);

      if (!mounted) return;
      setState(() => _step = _Step.concluido);
      HapticFeedback.mediumImpact();
      _snack('Adicionado à galeria! ✨', success: true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      debugPrint('[CreateGallery] $e');
      if (!mounted) return;
      setState(() => _step = _Step.erro);
      _snack('Erro ao publicar. Tente novamente.');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _step = _Step.idle);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? TClubColors.redDeep : const Color(0xFF3D0A0A),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      content: Text(msg,
          style: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: TClubColors.textoPrincipal,
          )),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TClubColors.bg,
      body: Stack(children: [
        // Linha de acento no topo
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                TClubColors.redDeep, TClubColors.redPrincipal,
                TClubColors.redClaro, TClubColors.redPrincipal, TClubColors.redDeep,
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Container(height: 0.5, color: TClubColors.border),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(children: [
                    _buildTabs(),
                    _buildTabContent(),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ),
            _buildPublicarBtn(),
          ]),
        ),
        if (_busy) _buildOverlay(),
      ]),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: TClubColors.dim, size: 18),
        onPressed: _busy ? null : () => Navigator.pop(context),
      ),
      const Expanded(
        child: Text('ADICIONAR À GALERIA',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TClubTypography.displayFont,
              fontSize: 16, letterSpacing: 4, color: TClubColors.branco,
            )),
      ),
      const SizedBox(width: 48),
    ]),
  );

  Widget _buildTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('TIPO DE CONTEÚDO',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 9, fontWeight: FontWeight.w700,
            letterSpacing: 3, color: TClubColors.redPrincipal,
          )),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(color: TClubColors.border, width: 0.8),
        ),
        child: TabBar(
          controller: _tabCtrl,
          indicatorColor: TClubColors.redPrincipal,
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: TClubColors.redPrincipal,
          unselectedLabelColor: TClubColors.subtle,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.photo_outlined, size: 15), text: 'FOTO'),
            Tab(icon: Icon(Icons.videocam_outlined, size: 15), text: 'VÍDEO'),
          ],
        ),
      ),
    ]),
  );

  Widget _buildTabContent() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _tabCtrl.index == 0
          ? KeyedSubtree(key: const ValueKey('foto'), child: _buildTabFoto())
          : KeyedSubtree(key: const ValueKey('video'), child: _buildTabVideo()),
    ),
  );

  // ── Tab foto ───────────────────────────────────────────────────────────────
  Widget _buildTabFoto() => Column(children: [
    GestureDetector(
      onTap: _showFotoSheet,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: _foto != null ? 300 : 180,
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(
            color: _foto != null
                ? TClubColors.redPrincipal.withOpacity(0.4)
                : TClubColors.border,
            width: _foto != null ? 1 : 0.8,
          ),
        ),
        child: _foto != null
            ? Stack(fit: StackFit.expand, children: [
                Image.file(_foto!, fit: BoxFit.cover),
                Positioned(
                  top: 8, right: 8,
                  child: Row(children: [
                    _MiniBtn(icon: Icons.edit_outlined, onTap: _showFotoSheet),
                    const SizedBox(width: 6),
                    _MiniBtn(icon: Icons.close, onTap: () => setState(() => _foto = null)),
                  ]),
                ),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TClubColors.redPrincipal.withOpacity(0.1),
                    border: Border.all(
                        color: TClubColors.redPrincipal.withOpacity(0.3), width: 1),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: TClubColors.redPrincipal, size: 26),
                ),
                const SizedBox(height: 12),
                const Text('TOQUE PARA ADICIONAR FOTO',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 2.5, color: TClubColors.subtle,
                    )),
                const SizedBox(height: 4),
                const Text('câmera ou galeria',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 11, color: TClubColors.subtle,
                    )),
              ]),
      ),
    ),
  ]);

  // ── Tab vídeo ──────────────────────────────────────────────────────────────
  Widget _buildTabVideo() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Player / placeholder
    GestureDetector(
      onTap: _video == null ? _showVideoSheet : _toggleVideoPlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: _video != null ? 340 : 180,
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(
            color: _video != null
                ? TClubColors.redPrincipal.withOpacity(0.4)
                : TClubColors.border,
            width: _video != null ? 1 : 0.8,
          ),
        ),
        child: _video != null && _videoCtrl != null && _videoCtrl!.value.isInitialized
            ? Stack(fit: StackFit.expand, children: [
                // Capa enquanto não está tocando
                if (!_videoPlaying && _coverBytes != null)
                  Positioned.fill(
                    child: Image.memory(_coverBytes!, fit: BoxFit.cover),
                  ),
                // Player
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoCtrl!.value.size.width,
                      height: _videoCtrl!.value.size.height,
                      child: VideoPlayer(_videoCtrl!),
                    ),
                  ),
                ),
                // Play/pause central
                Center(
                  child: AnimatedOpacity(
                    opacity: _videoPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.55),
                        border: Border.all(color: TClubColors.redPrincipal, width: 1.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ),
                // Botões de editar/remover
                Positioned(
                  top: 8, right: 8,
                  child: Row(children: [
                    _MiniBtn(icon: Icons.edit_outlined, onTap: _showVideoSheet),
                    const SizedBox(width: 6),
                    _MiniBtn(icon: Icons.close, onTap: _removerVideo),
                  ]),
                ),
                // Duração
                if (_videoDuration != null)
                  Positioned(
                    bottom: 8, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        border: Border.all(
                            color: TClubColors.redPrincipal.withOpacity(0.5), width: 0.8),
                      ),
                      child: Text(
                        _fmtDuration(_videoDuration!.inSeconds),
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 10, fontWeight: FontWeight.w700,
                          letterSpacing: 1, color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Progress bar
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _VideoProgressBar(controller: _videoCtrl!),
                ),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TClubColors.redPrincipal.withOpacity(0.1),
                    border: Border.all(
                        color: TClubColors.redPrincipal.withOpacity(0.3), width: 1),
                  ),
                  child: const Icon(Icons.video_call_outlined,
                      color: TClubColors.redPrincipal, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('TOQUE PARA ADICIONAR VÍDEO',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 2.5, color: TClubColors.subtle,
                    )),
                const SizedBox(height: 4),
                const Text('câmera ou galeria',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 11, color: TClubColors.subtle,
                    )),
              ]),
      ),
    ),

    // Botão de escolher capa (só aparece quando há vídeo)
    if (_video != null && _videoCtrl != null && _videoCtrl!.value.isInitialized) ...[
      const SizedBox(height: 10),
      _buildEscolherCapaBtn(),
    ],

    const SizedBox(height: 8),
    // Dica
    Row(children: [
      const Icon(Icons.info_outline_rounded,
          size: 11, color: TClubColors.subtle),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          'Vídeos da galeria têm no máximo 10 segundos.',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 9, letterSpacing: 0.5,
            color: TClubColors.subtle.withOpacity(0.7),
          ),
        ),
      ),
    ]),
  ]);

  // ── Botão de capa ──────────────────────────────────────────────────────────
  Widget _buildEscolherCapaBtn() => GestureDetector(
    onTap: _abrirSeletorCapa,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _capaPersonalizada
            ? TClubColors.redPrincipal.withOpacity(0.12)
            : TClubColors.bgCard,
        border: Border.all(
          color: _capaPersonalizada
              ? TClubColors.redPrincipal.withOpacity(0.6)
              : TClubColors.border,
          width: _capaPersonalizada ? 1.2 : 0.8,
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (_coverBytes != null)
          Container(
            width: 36, height: 36,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              border: Border.all(
                  color: TClubColors.redPrincipal.withOpacity(0.5), width: 1),
            ),
            // FIX: BoxFit.cover garante que o thumbnail quadrado não distorça
            child: Image.memory(_coverBytes!, fit: BoxFit.cover),
          ),
        Icon(
          _capaPersonalizada
              ? Icons.check_circle_rounded
              : Icons.photo_camera_outlined,
          color: _capaPersonalizada ? TClubColors.redPrincipal : TClubColors.subtle,
          size: 15,
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _capaPersonalizada ? 'CAPA PERSONALIZADA' : 'ESCOLHER CAPA',
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2,
              color: _capaPersonalizada ? TClubColors.redPrincipal : TClubColors.subtle,
            ),
          ),
          Text(
            _capaPersonalizada
                ? 'toque para trocar o frame'
                : 'selecione um frame do vídeo',
            style: const TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 9, letterSpacing: 0.5, color: TClubColors.subtle,
            ),
          ),
        ]),
      ]),
    ),
  );

  // ── Botão publicar ─────────────────────────────────────────────────────────
  Widget _buildPublicarBtn() {
    final can = _podePublicar;
    return Container(
      decoration: const BoxDecoration(
        color: TClubColors.bgAlt,
        border: Border(top: BorderSide(color: TClubColors.border, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      child: GestureDetector(
        onTap: can ? _publicar : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity, height: 52,
          decoration: BoxDecoration(
            color: _step == _Step.erro
                ? const Color(0xFFE85D5D)
                : can ? TClubColors.redPrincipal : TClubColors.bgCard,
            border: Border.all(
              color: can ? TClubColors.redPrincipal : TClubColors.border,
              width: 0.8,
            ),
            boxShadow: can
                ? [BoxShadow(
                    color: TClubColors.glow.withOpacity(0.35),
                    blurRadius: 16, spreadRadius: 1)]
                : null,
          ),
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: TClubColors.branco, strokeWidth: 2))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded,
                        color: can ? TClubColors.branco : TClubColors.subtle,
                        size: 16),
                    const SizedBox(width: 10),
                    Text('ADICIONAR À GALERIA',
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 12, fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: can ? TClubColors.branco : TClubColors.subtle,
                        )),
                  ]),
          ),
        ),
      ),
    );
  }

  // ── Overlay de progresso ───────────────────────────────────────────────────
  Widget _buildOverlay() {
    final label = switch (_step) {
      _Step.processandoVideo => 'PROCESSANDO VÍDEO...',
      _Step.uploadingMedia   => _tabCtrl.index == 1 ? 'ENVIANDO VÍDEO...' : 'ENVIANDO FOTO...',
      _Step.uploadingCover   => 'ENVIANDO CAPA...',
      _Step.salvando         => 'SALVANDO...',
      _                      => 'AGUARDE...',
    };
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 64, height: 64,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  color: TClubColors.redPrincipal,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  strokeWidth: 3,
                ),
                if (_uploadProgress > 0)
                  Text('${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
              ]),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 2.5, color: Colors.white,
                )),
          ]),
        ),
      ),
    );
  }

  // ── Sheets ─────────────────────────────────────────────────────────────────
  void _showFotoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TClubColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHandle(),
          const Text('SELECIONAR FOTO',
              style: TextStyle(
                fontFamily: TClubTypography.displayFont,
                fontSize: 16, letterSpacing: 5, color: TClubColors.textoPrincipal,
              )),
          const SizedBox(height: 16),
          Container(height: 0.5, color: TClubColors.border),
          _SheetTile(
            icon: Icons.photo_camera_outlined,
            label: 'CÂMERA', sublabel: 'Tirar foto agora',
            onTap: () => _pickFoto(ImageSource.camera),
          ),
          Container(height: 0.5, color: TClubColors.border),
          _SheetTile(
            icon: Icons.photo_library_outlined,
            label: 'GALERIA', sublabel: 'Escolher da galeria',
            onTap: () => _pickFoto(ImageSource.gallery),
          ),
          if (_foto != null) ...[
            Container(height: 0.5, color: TClubColors.border),
            _SheetTile(
              icon: Icons.delete_outline, label: 'REMOVER',
              sublabel: 'Continuar sem imagem', danger: true,
              onTap: () { Navigator.pop(context); setState(() => _foto = null); },
            ),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _showVideoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TClubColors.bgAlt,
      shape: const RoundedRectangleBorder(),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHandle(),
          const Text('SELECIONAR VÍDEO',
              style: TextStyle(
                fontFamily: TClubTypography.displayFont,
                fontSize: 16, letterSpacing: 5, color: TClubColors.textoPrincipal,
              )),
          const SizedBox(height: 16),
          Container(height: 0.5, color: TClubColors.border),
          _SheetTile(
            icon: Icons.videocam_outlined,
            label: 'CÂMERA', sublabel: 'Gravar vídeo agora',
            onTap: () => _pickVideo(ImageSource.camera),
          ),
          Container(height: 0.5, color: TClubColors.border),
          _SheetTile(
            icon: Icons.video_library_outlined,
            label: 'GALERIA', sublabel: 'Escolher da galeria',
            onTap: () => _pickVideo(ImageSource.gallery),
          ),
          if (_video != null) ...[
            Container(height: 0.5, color: TClubColors.border),
            _SheetTile(
              icon: Icons.delete_outline, label: 'REMOVER',
              sublabel: 'Continuar sem vídeo', danger: true,
              onTap: () { Navigator.pop(context); _removerVideo(); },
            ),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _sheetHandle() => Container(
    width: 36, height: 3,
    margin: const EdgeInsets.only(top: 12, bottom: 20),
    decoration: BoxDecoration(
      color: TClubColors.border, borderRadius: BorderRadius.circular(2)),
  );

  String _fmtDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  FRAME PICKER SHEET
//  FIX: preview usa AspectRatio(1.0) + BoxFit.cover para garantir que o frame
//  capturado pelo RepaintBoundary tenha exatamente a proporção 1:1 dos cards
//  do grid (crossAxisCount: 3, mainAxisExtent: 120, childAspectRatio: 1.0).
//  Antes era Container(height: 300) com FittedBox.contain → letterbox preto.
// ══════════════════════════════════════════════════════════════════════════════
class _FramePickerSheet extends StatefulWidget {
  const _FramePickerSheet({
    required this.videoCtrl,
    required this.totalDuration,
    required this.onConfirm,
    this.currentCover,
  });

  final VideoPlayerController videoCtrl;
  final Duration totalDuration;
  final Uint8List? currentCover;
  final void Function(Uint8List bytes) onConfirm;

  @override
  State<_FramePickerSheet> createState() => _FramePickerSheetState();
}

class _FramePickerSheetState extends State<_FramePickerSheet> {
  late double _sliderValue;
  bool _capturando = false;
  bool _seekando = false;
  final _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final total = widget.totalDuration.inMilliseconds;
    final pos = widget.videoCtrl.value.position.inMilliseconds;
    _sliderValue = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    widget.videoCtrl.pause();
  }

  int get _posMs =>
      (_sliderValue * widget.totalDuration.inMilliseconds).round();

  Future<void> _onSliderChanged(double v) async {
    if (_seekando) return;
    _seekando = true;
    setState(() => _sliderValue = v);
    await widget.videoCtrl.seekTo(Duration(milliseconds:
        (v * widget.totalDuration.inMilliseconds).round()));
    widget.videoCtrl.pause();
    if (mounted) setState(() => _seekando = false);
  }

  Future<void> _confirmar() async {
    if (_capturando) return;
    setState(() => _capturando = true);
    try {
      await widget.videoCtrl.seekTo(Duration(milliseconds: _posMs));
      widget.videoCtrl.pause();
      await Future.delayed(const Duration(milliseconds: 150));
      await _nextFrame();
      await _nextFrame();

      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RepaintBoundary não encontrado');

      final dpr = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 2.0;
      final image = await boundary.toImage(pixelRatio: dpr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('toByteData retornou null');

      if (!mounted) return;
      Navigator.pop(context);
      widget.onConfirm(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('[FramePicker] $e');
      if (mounted) {
        setState(() => _capturando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF3D0A0A),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(),
          content: Text('Não foi possível capturar o frame.',
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 11, color: TClubColors.textoPrincipal, letterSpacing: 1,
              )),
        ));
      }
    }
  }

  Future<void> _nextFrame() {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.complete());
    return c.future;
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.totalDuration.inMilliseconds;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: TClubColors.bgAlt,
        border: Border(top: BorderSide(color: TClubColors.redPrincipal, width: 1.5)),
      ),
      child: Column(children: [
        Container(
          width: 36, height: 3,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(
            color: TClubColors.border, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ESCOLHER CAPA',
                    style: TextStyle(
                      fontFamily: TClubTypography.displayFont,
                      fontSize: 16, letterSpacing: 4, color: TClubColors.textoPrincipal,
                    )),
                SizedBox(height: 3),
                Text('arraste o slider para selecionar o frame',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 10, letterSpacing: 1, color: TClubColors.subtle,
                    )),
              ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: TClubColors.bgCard,
                  border: Border.all(color: TClubColors.border, width: 0.8),
                ),
                child: const Icon(Icons.close, color: TClubColors.subtle, size: 16),
              ),
            ),
          ]),
        ),
        Container(height: 0.5, color: TClubColors.border),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(children: [

              // ── Preview do frame ─────────────────────────────────────────
              // FIX: AspectRatio(1.0) garante proporção quadrada em qualquer
              // largura de tela. FittedBox.cover dentro do RepaintBoundary
              // faz crop centralizado igual ao GalleryGridTile — sem barras
              // pretas e sem distorção. O RepaintBoundary captura exatamente
              // o que será exibido no card do grid (120×120).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Stack(
                  children: [
                    // Fundo preto atrás do AspectRatio (visible em telas largas)
                    ColoredBox(
                      color: Colors.black,
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: RepaintBoundary(
                          key: _repaintKey,
                          child: ClipRect(
                            child: FittedBox(
                              // FIX: cover → crop centralizado 1:1, sem letterbox
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: widget.videoCtrl.value.size.width,
                                height: widget.videoCtrl.value.size.height,
                                child: VideoPlayer(widget.videoCtrl),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Overlay de loading durante seek
                    if (_seekando)
                      Positioned.fill(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: ColoredBox(
                            color: Colors.black.withOpacity(0.35),
                            child: const Center(
                              child: SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                    color: TClubColors.redPrincipal, strokeWidth: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Timecode — posicionado sobre o AspectRatio
                    Positioned(
                      bottom: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          border: Border.all(
                              color: TClubColors.redPrincipal.withOpacity(0.6), width: 0.8),
                        ),
                        child: Text(_fmt(_posMs),
                            style: const TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 13, fontWeight: FontWeight.w700,
                              letterSpacing: 1, color: Colors.white,
                            )),
                      ),
                    ),
                    // Badge "CAPA"
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: TClubColors.redPrincipal.withOpacity(0.9),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.image_outlined, color: Colors.white, size: 10),
                          SizedBox(width: 4),
                          Text('CAPA',
                              style: TextStyle(
                                fontFamily: TClubTypography.bodyFont,
                                fontSize: 8, fontWeight: FontWeight.w700,
                                letterSpacing: 2, color: Colors.white,
                              )),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),

              // Slider
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(children: [
                  Row(children: [
                    Text(_fmt(_posMs),
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 11, fontWeight: FontWeight.w700,
                          letterSpacing: 1, color: TClubColors.redPrincipal,
                        )),
                    const Spacer(),
                    Text(_fmt(totalMs),
                        style: const TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 11, letterSpacing: 1, color: TClubColors.subtle,
                        )),
                  ]),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: TClubColors.redPrincipal,
                      inactiveTrackColor: TClubColors.border,
                      thumbColor: TClubColors.redPrincipal,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8, elevation: 0),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      overlayColor: TClubColors.redPrincipal.withOpacity(0.15),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _sliderValue,
                      min: 0.0, max: 1.0,
                      onChanged: _onSliderChanged,
                      onChangeEnd: (v) async {
                        setState(() => _sliderValue = v);
                        await widget.videoCtrl.seekTo(Duration(
                            milliseconds: (v * totalMs).round()));
                        widget.videoCtrl.pause();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('← arraste para navegar pelo vídeo →',
                      style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 9, letterSpacing: 1.5, color: TClubColors.subtle,
                      )),
                ]),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ),

        // Botão confirmar
        Container(
          decoration: const BoxDecoration(
            color: TClubColors.bgAlt,
            border: Border(top: BorderSide(color: TClubColors.border, width: 0.5)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
          child: GestureDetector(
            onTap: _capturando ? null : _confirmar,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                color: TClubColors.redPrincipal,
                boxShadow: [
                  BoxShadow(
                    color: TClubColors.glow.withOpacity(0.35),
                    blurRadius: 16, spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: _capturando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text('USAR ESTE FRAME COMO CAPA',
                            style: TextStyle(
                              fontFamily: TClubTypography.bodyFont,
                              fontSize: 12, fontWeight: FontWeight.w700,
                              letterSpacing: 2, color: Colors.white,
                            )),
                      ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════
class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        border: Border.all(color: TClubColors.borderMid, width: 0.8),
      ),
      child: Icon(icon, color: TClubColors.branco, size: 15),
    ),
  );
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool danger;
  final VoidCallback onTap;
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE85D5D) : TClubColors.textoPrincipal;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border.all(color: color.withOpacity(0.3), width: 0.8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 13, fontWeight: FontWeight.w700,
                  letterSpacing: 2, color: color,
                )),
            Text(sublabel,
                style: const TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 10, letterSpacing: 0.5, color: TClubColors.subtle,
                )),
          ]),
        ]),
      ),
    );
  }
}

class _VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoProgressBar({required this.controller});

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final pos = widget.controller.value.position.inMilliseconds.toDouble();
    final total = widget.controller.value.duration.inMilliseconds.toDouble();
    final pct = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      height: 3,
      color: Colors.white.withOpacity(0.15),
      child: FractionallySizedBox(
        widthFactor: pct,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [TClubColors.redDeep, TClubColors.redPrincipal],
            ),
          ),
        ),
      ),
    );
  }
}

