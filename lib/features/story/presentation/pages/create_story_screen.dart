// lib/screens/screens_home/home_screen/posts/create_story_screen.dart
// ALTERAÇÕES vs original:
//   • Removido: import 'package:firebase_storage/firebase_storage.dart'
//   • Adicionado: import cloudinary_service.dart
//   • Método _publicar: uploads reescritos para CloudinaryService
//   • Paleta de cores migrada para padrão de match_profile_page (TClubTheme claro)
//   • _gravarVideoCamera: usa ImagePicker com ImageSource.camera (sem CameraX)
//   • FIX: _videoProcessProgress e _videoProcessStep movidos para dentro da classe
//   • FIX: _gravarVideoCamera só reseta/exibe overlay APÓS picker retornar arquivo
//   • FIX: duração lida via FFprobe (evita crash Media3/ExoPlayer no controller temporário)
//   • FIX: RenderFlex overflow — botões de visibilidade envolvidos em Flexible

import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:video_compress/video_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tclub/features/story/data/models/story_model.dart';
import 'package:tclub/features/post/data/services/cloudinary_service.dart';
import 'package:video_player/video_player.dart';
import 'package:tclub/core/theme/tclub_theme.dart';
import 'package:tclub/features/story/data/services/story_service.dart';
import 'package:tclub/core/services/media/videos_trim_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CRIAR STORY SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class CreateStoryScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CreateStoryScreen({super.key, required this.userData});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

enum _PermissaoStatus { verificando, pendente, negadoPermanente, concedido }

class _Overlay {
  final String conteudo;
  final bool isEmoji;
  double dx;
  double dy;
  double scale;

  _Overlay({
    required this.conteudo,
    required this.isEmoji,
    required this.dx,
    required this.dy,
    this.scale = 1.0,
  });
}

enum _PublishStep {
  idle,
  processandoVideo,
  comprimindo,
  uploadingMedia,
  salvando,
  concluido,
  erro
}

class _CreateStoryScreenState extends State<CreateStoryScreen>
    with TickerProviderStateMixin {
  static const int _maxVideoSeconds = 10;

  // ── Câmera ──────────────────────────────────────────────────────────────────
  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _flashOn = false;
  bool _cameraReady = false;

  // ── Controllers ─────────────────────────────────────────────────────────────
  double _compressProgress = 0.0;
  final _textCtrl = TextEditingController();
  final _textFocus = FocusNode();
  final _picker = ImagePicker();

  // ── Animações ────────────────────────────────────────────────────────────────
  late AnimationController _captureAnimCtrl;
  late AnimationController _toolbarAnimCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _permissaoAnimCtrl;
  late Animation<double> _captureAnim;
  late Animation<double> _toolbarAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _permissaoAnim;

  // ── Permissões ───────────────────────────────────────────────────────────────
  _PermissaoStatus _permissaoCamera = _PermissaoStatus.verificando;
  _PermissaoStatus _permissaoStorage = _PermissaoStatus.verificando;
  bool _solicitando = false;

  // ── Estado geral ─────────────────────────────────────────────────────────────
  _StoryMode _modoAtual = _StoryMode.camera;
  _StoryStep _etapa = _StoryStep.captura;
  File? _midia;
  String? _emojiSelecionado;
  _TextStyle _estiloTexto = _TextStyle.branco;
  _Fundo _fundoSelecionado = _Fundo.escuro;
  bool _capturando = false;

  // ── Vídeo ────────────────────────────────────────────────────────────────────
  VideoPlayerController? _videoCtrl;
  Duration? _videoDuration;
  bool _videoPlaying = false;

  // ── Publicação ────────────────────────────────────────────────────────────────
  _PublishStep _publishStep = _PublishStep.idle;
  double _uploadProgress = 0.0;
  String? _erroMsg;
  String _visibilidade = 'publico';

  // ── Progresso de processamento de vídeo (instância, não global) ───────────────
  double _videoProcessProgress = 0.0;
  String _videoProcessStep = '';

  // ── Ajuste de imagem da galeria ──────────────────────────────────────────────
  double _ajusteScale = 1.0;
  double _ajusteRotation = 0.0;
  Offset _ajusteOffset = Offset.zero;

  bool get _publicando =>
      _publishStep != _PublishStep.idle &&
      _publishStep != _PublishStep.concluido &&
      _publishStep != _PublishStep.erro;

  bool get _videoDuracaoValida =>
      _videoDuration != null &&
      _videoDuration!.inSeconds <= _maxVideoSeconds &&
      _videoDuration!.inSeconds > 0;

  // ── Overlays ─────────────────────────────────────────────────────────────────
  final List<_Overlay> _overlays = [];
  bool _toolTextOpen = false;
  bool _toolEmojiOpen = false;
  int? _overlayAtivo;

  String _textoCentral = '';

  double _editorW = 0;
  double _editorH = 0;

  static const _emojis = [
    '🔥','🎉','💃','🥂','😈','✨','💋','👑','🌙','⚡',
    '🍸','🎶','🤩','😍','💜','🩷','🎊','🌟','🪩','🎸',
  ];

  static const _fundoGradients = {
    _Fundo.escuro:    [Color(0xFF0D0010), Color(0xFF1A0020)],
    _Fundo.rosaFogo:  [Color(0xFF3D0018), Color(0xFF8B003A)],
    _Fundo.roxo:      [Color(0xFF0D0030), Color(0xFF4B0070)],
    _Fundo.ouro:      [Color(0xFF2A1500), Color(0xFF6B3500)],
    _Fundo.azulNoite: [Color(0xFF000518), Color(0xFF001240)],
    _Fundo.verde:     [Color(0xFF001A0A), Color(0xFF003A18)],
  };

  // ══════════════════════════════════════════════════════════════════════════
  //  INIT / DISPOSE
  // ══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();

    _captureAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _captureAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
        CurvedAnimation(parent: _captureAnimCtrl, curve: Curves.easeInOut));

    _toolbarAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _toolbarAnim =
        CurvedAnimation(parent: _toolbarAnimCtrl, curve: Curves.easeOutCubic);
    _toolbarAnimCtrl.forward();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _permissaoAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _permissaoAnim =
        CurvedAnimation(parent: _permissaoAnimCtrl, curve: Curves.easeOutCubic);

    _verificarPermissoes();
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    _captureAnimCtrl.dispose();
    _toolbarAnimCtrl.dispose();
    _pulseCtrl.dispose();
    _permissaoAnimCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PERMISSÕES
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _verificarPermissoes() async {
    final camera = await Permission.camera.status;
    final storage = await _storageStatus();
    if (!mounted) return;
    setState(() {
      _permissaoCamera = _mapear(camera);
      _permissaoStorage = _mapear(storage);
    });
    _permissaoAnimCtrl.forward();
    if (_permissaoCamera == _PermissaoStatus.concedido) _iniciarCamera();
  }

  Future<PermissionStatus> _storageStatus() async {
    if (Platform.isAndroid) {
      final m = await Permission.photos.status;
      if (m != PermissionStatus.denied &&
          m != PermissionStatus.permanentlyDenied) return m;
      return Permission.storage.status;
    }
    return Permission.photos.status;
  }

  _PermissaoStatus _mapear(PermissionStatus s) {
    switch (s) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return _PermissaoStatus.concedido;
      case PermissionStatus.permanentlyDenied:
        return _PermissaoStatus.negadoPermanente;
      default:
        return _PermissaoStatus.pendente;
    }
  }

  Future<void> _solicitarPermissoes() async {
    if (_solicitando) return;
    setState(() => _solicitando = true);
    HapticFeedback.mediumImpact();
    final camera = await Permission.camera.request();
    PermissionStatus storage;
    if (Platform.isAndroid) {
      storage = await Permission.photos.request();
      if (storage == PermissionStatus.denied ||
          storage == PermissionStatus.permanentlyDenied) {
        storage = await Permission.storage.request();
      }
    } else {
      storage = await Permission.photos.request();
    }
    if (!mounted) return;
    setState(() {
      _solicitando = false;
      _permissaoCamera = _mapear(camera);
      _permissaoStorage = _mapear(storage);
    });
    if (_permissaoCamera == _PermissaoStatus.concedido) {
      HapticFeedback.mediumImpact();
      _iniciarCamera();
    }
  }

  bool get _cameraLiberada => _permissaoCamera == _PermissaoStatus.concedido;
  bool get _storageLiberado => _permissaoStorage == _PermissaoStatus.concedido;
  bool get _negadoPerm =>
      _permissaoCamera == _PermissaoStatus.negadoPermanente ||
      _permissaoStorage == _PermissaoStatus.negadoPermanente;

  // ══════════════════════════════════════════════════════════════════════════
  //  CÂMERA
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _iniciarCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _montarCamera(_cameraIndex);
    } catch (_) {}
  }

  Future<void> _montarCamera(int index) async {
    await _cameraCtrl?.dispose();
    if (!mounted) return;
    final ctrl = CameraController(_cameras[index], ResolutionPreset.medium,
        enableAudio: true);
    try {
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      await ctrl.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      setState(() { _cameraCtrl = ctrl; _cameraReady = true; });
    } catch (_) { ctrl.dispose(); }
  }

  Future<void> _virarCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _cameraReady = false);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _montarCamera(_cameraIndex);
  }

  Future<void> _toggleFlash() async {
    if (_cameraCtrl == null || !_cameraReady) return;
    _flashOn = !_flashOn;
    await _cameraCtrl!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _tirarFoto() async {
    if (_capturando || _cameraCtrl == null || !_cameraReady) return;
    setState(() => _capturando = true);
    HapticFeedback.mediumImpact();
    await _captureAnimCtrl.forward();
    await _captureAnimCtrl.reverse();
    try {
      final xFile = await _cameraCtrl!.takePicture();
      if (!mounted) return;
      setState(() {
        _midia = File(xFile.path);
        _etapa = _StoryStep.edicao;
        _capturando = false;
      });
      _toolbarAnimCtrl..reset()..forward();
    } catch (_) {
      setState(() => _capturando = false);
    }
  }

  Future<void> _pickGaleria() async {
    final p = await _picker.pickImage(source: ImageSource.gallery);
    if (p == null) return;
    if (!mounted) return;
    setState(() { _midia = File(p.path); _etapa = _StoryStep.edicao; });
    _toolbarAnimCtrl..reset()..forward();
  }

  // ── Gravação via câmera nativa (sem CameraX/Media3) ──────────────────────
  // FIX: o overlay de processamento só é ativado APÓS o picker retornar
  // um arquivo válido, evitando que fique preso em 0% quando o usuário cancela.
  Future<void> _gravarVideoCamera() async {
    // Aguarda o picker sem alterar nenhum estado visual —
    // o overlay NÃO deve aparecer antes de termos um arquivo.
    final p = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: Duration(seconds: _maxVideoSeconds),
    );

    // Usuário cancelou: nada a fazer.
    if (p == null) return;
    if (!mounted) return;

    // Só aqui, com arquivo em mãos, resetamos e exibimos o overlay.
    setState(() {
      _videoProcessProgress = 0.0;
      _videoProcessStep = '';
    });

    await _processarVideoFile(File(p.path));
  }

  Future<void> _pickGaleriaVideo() async {
    final p = await _picker.pickVideo(source: ImageSource.gallery);
    if (p == null) return;
    if (!mounted) return;

    setState(() {
      _videoProcessProgress = 0.0;
      _videoProcessStep = '';
    });

    await _processarVideoFile(File(p.path));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PROCESSAR VÍDEO
  // ══════════════════════════════════════════════════════════════════════════
  // Lê a duração do vídeo via FFprobe, sem instanciar VideoPlayerController.
  // Isso evita o crash de versão conflitante do Media3/ExoPlayer num controller
  // temporário usado apenas para obter metadados.
  static Future<int> _getDurationSec(File file) async {
    try {
      final session = await FFprobeKit.getMediaInformation(file.path);
      final info = session.getMediaInformation();
      if (info != null) {
        final durStr = info.getDuration(); // duração em segundos (string)
        if (durStr != null) {
          final dur = double.tryParse(durStr);
          if (dur != null && dur > 0) return dur.ceil();
        }
      }
    } catch (e) {
      debugPrint('[Story] _getDurationSec via FFprobe falhou: $e');
    }
    // Fallback: VideoCompress (não usa ExoPlayer)
    try {
      final info = await VideoCompress.getMediaInfo(file.path);
      final ms = (info.duration ?? 0).toDouble();
      return ms > 1000 ? (ms / 1000).ceil() : ms.ceil().toInt();
    } catch (e) {
      debugPrint('[Story] _getDurationSec via VideoCompress falhou: $e');
    }
    return 0;
  }

  Future<void> _processarVideoFile(File file) async {
    setState(() {
      _publishStep = _PublishStep.processandoVideo;
      _videoProcessProgress = 0.0;
      _videoProcessStep = 'Analisando vídeo...';
    });

    // Usa FFprobe para ler a duração — não instancia VideoPlayerController
    // aqui para evitar o conflito de versão do Media3/ExoPlayer.
    final durationSec = await _getDurationSec(file);

    if (!mounted) return;

    File videoParaCarregar = file;

    if (durationSec > _maxVideoSeconds) {
      _atualizarProgressoVideo(0.3, 'Cortando vídeo para $_maxVideoSeconds segundos...');
      try {
        final trimmed = await VideoTrimService.trim(
          file: file,
          maxSeconds: _maxVideoSeconds,
        );
        if (!mounted) { try { trimmed.deleteSync(); } catch (_) {} return; }
        videoParaCarregar = trimmed;
        if (trimmed.path != file.path) { try { file.deleteSync(); } catch (_) {} }
        _atualizarProgressoVideo(0.7, 'Vídeo cortado com sucesso! ✂️');
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('[VideoTrim] $e');
        _atualizarProgressoVideo(0.5, 'Usando vídeo original...');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } else {
      _atualizarProgressoVideo(0.5, 'Vídeo dentro do limite de tempo');
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;

    _atualizarProgressoVideo(0.8, 'Carregando preview...');

    final playerCtrl = VideoPlayerController.file(videoParaCarregar);
    await playerCtrl.initialize();
    playerCtrl.setLooping(true);
    playerCtrl.addListener(() {
      if (mounted) setState(() => _videoPlaying = playerCtrl.value.isPlaying);
    });

    if (!mounted) { await playerCtrl.dispose(); return; }

    _atualizarProgressoVideo(1.0, 'Pronto!');
    await Future.delayed(const Duration(milliseconds: 200));

    await _videoCtrl?.dispose();
    setState(() {
      _midia = videoParaCarregar;
      _videoCtrl = playerCtrl;
      _videoDuration = playerCtrl.value.duration;
      _videoPlaying = false;
      _etapa = _StoryStep.edicao;
      _capturando = false;
      _publishStep = _PublishStep.idle;
      _videoProcessProgress = 0.0;
      _videoProcessStep = '';
    });

    _toolbarAnimCtrl..reset()..forward();
    _snack('Vídeo pronto! ✅', success: true);
  }

  void _atualizarProgressoVideo(double progress, String step) {
    if (!mounted) return;
    setState(() {
      _videoProcessProgress = progress;
      _videoProcessStep = step;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUBLICAR — Cloudinary
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> _publicar() async {
    if (_publicando) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    final uid = FirebaseAuth.instance.currentUser?.uid ??
        (widget.userData['uid'] as String?) ??
        (widget.userData['id'] as String?) ??
        '';
    if (uid.isEmpty) {
      _snack('Erro: usuário não autenticado.');
      return;
    }

    setState(() {
      _publishStep = _PublishStep.comprimindo;
      _compressProgress = 0.0;
      _uploadProgress = 0.0;
      _erroMsg = null;
    });

    try {
      String? mediaUrl;
      int? videoDurationSec;
      final isVideoMode = _modoAtual == _StoryMode.video;

      if (isVideoMode && _midia != null) {
        videoDurationSec = _videoDuration?.inSeconds;

        File videoParaUpload = _midia!;
        try {
          videoParaUpload = await VideoTrimService.trimAndCompress(
            file: _midia!,
            maxSeconds: _maxVideoSeconds,
          );
        } catch (e) {
          debugPrint('[Compress] Falhou, usando original: $e');
        }

        if (!mounted) return;

        setState(() {
          _publishStep = _PublishStep.uploadingMedia;
          _uploadProgress = 0.0;
        });

        final ts = DateTime.now().millisecondsSinceEpoch;
        mediaUrl = await CloudinaryService.instance.uploadFile(
          file: videoParaUpload,
          resourceType: CloudinaryResourceType.video,
          folder: 'stories/$uid/videos',
          publicId: '$ts',
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );

        if (videoParaUpload.path != _midia!.path) {
          try { videoParaUpload.deleteSync(); } catch (_) {}
        }

        if (mediaUrl == null) throw Exception('Upload do vídeo falhou.');

      } else if (_modoAtual == _StoryMode.camera && _midia != null) {
        setState(() {
          _publishStep = _PublishStep.uploadingMedia;
          _uploadProgress = 0.0;
        });

        mediaUrl = await CloudinaryService.instance.uploadFile(
          file: _midia!,
          resourceType: CloudinaryResourceType.image,
          folder: 'stories/$uid',
          onProgress: (p) {
            if (mounted) setState(() => _uploadProgress = p);
          },
        );

        if (mediaUrl == null) throw Exception('Upload da foto falhou.');
      }

      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.salvando);

      final edW = _editorW > 0 ? _editorW : MediaQuery.of(context).size.width;
      final edH = _editorH > 0 ? _editorH : MediaQuery.of(context).size.height;
      final overlaysSalvar = _overlays
          .map((o) => StoryOverlay(
                type: o.isEmoji ? 'emoji' : 'text',
                content: o.conteudo,
                posX: (o.dx / edW).clamp(0.0, 1.0),
                posY: (o.dy / edH).clamp(0.0, 1.0),
                scale: o.scale,
                style: o.isEmoji ? null : {'fontStyle': _estiloTexto.name},
              ))
          .toList();

      await StoryService.instance.createStory(
        userId: uid,
        userName: (widget.userData['name'] as String? ?? 'Anônimo').toUpperCase(),
        userAvatar: widget.userData['avatar'] as String?,
        type: _modoAtual.name,
        mediaUrl: mediaUrl,
        background: _fundoSelecionado.name,
        centralText: _textoCentral.isEmpty ? null : _textoCentral,
        centralEmoji: _emojiSelecionado,
        textStyle: _estiloTexto.name,
        overlays: overlaysSalvar,
        visibilidade: _visibilidade,
        videoDuration: videoDurationSec,
      );

      if (!mounted) return;
      setState(() => _publishStep = _PublishStep.concluido);
      HapticFeedback.mediumImpact();
      _snack('Story publicado! ✨ Expira em 24h', success: true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publishStep = _PublishStep.erro;
        _erroMsg = 'Erro ao publicar. Tente novamente.';
      });
      _snack(_erroMsg!);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _publishStep = _PublishStep.idle);
    }
  }

  void _toggleVideoPlay() {
    if (_videoCtrl == null || !_videoCtrl!.value.isInitialized) return;
    setState(() {
      if (_videoCtrl!.value.isPlaying) {
        _videoCtrl!.pause();
        _videoPlaying = false;
      } else {
        _videoCtrl!.play();
        _videoPlaying = true;
      }
    });
  }

  void _voltarCaptura() {
    _videoCtrl?.dispose();
    setState(() {
      _midia = null;
      _etapa = _StoryStep.captura;
      _ajusteScale = 1.0;
      _ajusteRotation = 0.0;
      _ajusteOffset = Offset.zero;
      _overlays.clear();
      _toolTextOpen = false;
      _toolEmojiOpen = false;
      _overlayAtivo = null;
      _textoCentral = '';
      _emojiSelecionado = null;
      _publishStep = _PublishStep.idle;
      _uploadProgress = 0.0;
      _erroMsg = null;
      _editorW = 0;
      _editorH = 0;
      _videoCtrl = null;
      _videoDuration = null;
      _videoPlaying = false;
      _videoProcessProgress = 0.0;
      _videoProcessStep = '';
    });
    _toolbarAnimCtrl..reset()..forward();
    if (_cameraLiberada && (_cameraCtrl == null || !_cameraReady)) {
      _iniciarCamera();
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: success ? TClubColors.bgCard : TClubColors.errorPale,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: success ? TClubColors.borderMid : TClubColors.error.withOpacity(0.5),
          width: 0.7,
        ),
      ),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      content: Row(children: [
        Icon(
          success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          size: 14,
          color: success ? TClubColors.redPrincipal : TClubColors.error,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            msg,
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: success ? TClubColors.textoPrincipal : TClubColors.errorDeep,
            ),
          ),
        ),
      ]),
    ));
  }

  void _confirmarTexto() {
    final txt = _textCtrl.text.trim();
    if (txt.isEmpty) return;
    if (_etapa == _StoryStep.captura && _modoAtual == _StoryMode.texto) {
      setState(() {
        _textoCentral = txt;
        _textCtrl.clear();
        _etapa = _StoryStep.edicao;
        _toolTextOpen = false;
      });
      FocusScope.of(context).unfocus();
      HapticFeedback.mediumImpact();
      _toolbarAnimCtrl..reset()..forward();
      return;
    }
    final edW = _editorW > 0 ? _editorW : MediaQuery.of(context).size.width;
    final edH = _editorH > 0 ? _editorH : MediaQuery.of(context).size.height;
    setState(() {
      _overlays.add(_Overlay(
        conteudo: txt,
        isEmoji: false,
        dx: edW * 0.5,
        dy: edH * 0.42 + (_overlays.length * 52.0),
      ));
      _textCtrl.clear();
      _toolTextOpen = false;
    });
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
  }

  void _confirmarEmoji() {
    if (_emojiSelecionado == null) return;
    setState(() {
      _etapa = _StoryStep.edicao;
      _toolTextOpen = false;
      _toolEmojiOpen = false;
    });
    HapticFeedback.mediumImpact();
    _toolbarAnimCtrl..reset()..forward();
  }

  void _adicionarEmojiOverlay(String emoji) {
    final edW = _editorW > 0 ? _editorW : MediaQuery.of(context).size.width;
    final edH = _editorH > 0 ? _editorH : MediaQuery.of(context).size.height;
    final rng = math.Random();
    setState(() {
      _overlays.add(_Overlay(
        conteudo: emoji,
        isEmoji: true,
        dx: edW * (0.35 + rng.nextDouble() * 0.3),
        dy: edH * (0.35 + rng.nextDouble() * 0.2),
        scale: 1.0,
      ));
      _toolEmojiOpen = false;
    });
    HapticFeedback.selectionClick();
  }

  void _removerOverlay(int index) {
    setState(() { _overlays.removeAt(index); _overlayAtivo = null; });
    HapticFeedback.mediumImpact();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: TClubColors.bg,
        body: Stack(
          children: [
            FadeTransition(
              opacity: _permissaoAnim,
              child: _cameraLiberada
                  ? (_etapa == _StoryStep.captura
                      ? _buildCapturaStep()
                      : _buildEdicaoStep())
                  : _buildPermissaoGate(),
            ),
            if (_publishStep == _PublishStep.processandoVideo)
              _buildVideoProcessOverlay(),
          ],
        ),
      ),
    );
  }

  // ── Overlay de processamento de vídeo ─────────────────────────────────────
  Widget _buildVideoProcessOverlay() {
    return Positioned.fill(
      child: Container(
        color: TClubColors.bg.withOpacity(0.94),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: TClubColors.bgCard,
              border: Border.all(color: TClubColors.borderMid, width: 0.8),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: TClubColors.glow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _videoProcessProgress,
                        color: TClubColors.redPrincipal,
                        backgroundColor: TClubColors.redPale,
                        strokeWidth: 3,
                      ),
                      Icon(Icons.video_library_outlined,
                          color: TClubColors.redPrincipal, size: 36),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'PROCESSANDO VÍDEO',
                  style: TextStyle(
                    fontFamily: TClubTypography.displayFont,
                    fontSize: 18,
                    letterSpacing: 5,
                    color: TClubColors.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _videoProcessStep,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 13,
                    letterSpacing: 0.3,
                    color: TClubColors.textoMuted,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _videoProcessProgress,
                    backgroundColor: TClubColors.redPale,
                    color: TClubColors.redPrincipal,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${(_videoProcessProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: TClubColors.redPrincipal,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: TClubColors.redPrincipal.withOpacity(0.07),
                    border: Border.all(color: TClubColors.borderMid, width: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 15, color: TClubColors.redPrincipal),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Preparando seu vídeo para o story...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TClubTypography.bodyFont,
                            fontSize: 11,
                            letterSpacing: 0.3,
                            color: TClubColors.textoSecundario,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GATE DE PERMISSÕES
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPermissaoGate() {
    return Stack(children: [
      Positioned.fill(child: Container(
        color: TClubColors.bg,
        child: CustomPaint(
          painter: _ParticlePainter(
            color: TClubColors.redPrincipal, seed: 7, count: 40,
          ),
        ),
      )),
      Positioned.fill(child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.8,
            colors: [
              TClubColors.glow.withOpacity(0.5),
              Colors.transparent,
            ],
          ),
        ),
      )),
      _neonLine(),
      SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Row(children: [
            _IconBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
            const Spacer(),
            _storyLabel(),
            const Spacer(),
            const SizedBox(width: 40),
          ]),
        ),
        const Spacer(),
        ScaleTransition(
          scale: _pulseAnim,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: TClubColors.border, width: 1),
                gradient: RadialGradient(colors: [
                  TClubColors.glow.withOpacity(0.4),
                  Colors.transparent,
                ]),
              ),
            ),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TClubColors.redPale,
                border: Border.all(color: TClubColors.redPrincipal.withOpacity(0.5), width: 1.5),
                boxShadow: TClubGlow.redPrincipal(blur: 20),
              ),
              child: Icon(Icons.photo_camera_outlined,
                  color: TClubColors.redPrincipal, size: 34),
            ),
          ]),
        ),
        const SizedBox(height: 32),
        Text(
          'ACESSO NECESSÁRIO',
          style: TextStyle(
            fontFamily: TClubTypography.displayFont,
            fontSize: 22,
            letterSpacing: 5,
            color: TClubColors.textoPrincipal,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Para criar stories incríveis, o Tclub precisa acessar sua câmera e galeria.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 13,
              letterSpacing: 0.3,
              height: 1.6,
              color: TClubColors.textoMuted,
            ),
          ),
        ),
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            _PermissaoCard(
              icon: Icons.photo_camera_outlined,
              titulo: 'CÂMERA',
              descricao: 'Tirar fotos e gravar vídeos',
              status: _permissaoCamera,
            ),
            const SizedBox(height: 12),
            _PermissaoCard(
              icon: Icons.photo_library_outlined,
              titulo: 'GALERIA',
              descricao: 'Escolher imagens e vídeos',
              status: _permissaoStorage,
            ),
          ]),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _negadoPerm ? _btnConfiguracoes() : _btnPermitir(),
        ),
        if (_negadoPerm) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Você bloqueou permanentemente. Vá em Configurações para habilitar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 11,
                color: TClubColors.textoMuted,
              ),
            ),
          ),
        ],
        const Spacer(),
        const SizedBox(height: 24),
      ])),
    ]);
  }

  Widget _btnPermitir() => GestureDetector(
    onTap: _solicitando ? null : _solicitarPermissoes,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TClubColors.redDeep, TClubColors.redPrincipal],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: TClubColors.redPrincipal, width: 1),
        boxShadow: TClubGlow.redPrincipal(blur: 24, spread: 2),
      ),
      child: Center(
        child: _solicitando
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  color: TClubColors.branco, strokeWidth: 2,
                ),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.lock_open_rounded, color: TClubColors.branco, size: 18),
                SizedBox(width: 10),
                Text(
                  'PERMITIR ACESSO',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: TClubColors.branco,
                  ),
                ),
              ]),
      ),
    ),
  );

  Widget _btnConfiguracoes() => GestureDetector(
    onTap: () => openAppSettings(),
    child: Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: TClubColors.bgCard,
        border: Border.all(color: TClubColors.borderMid, width: 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.settings_outlined, color: TClubColors.redPrincipal, size: 18),
        const SizedBox(width: 10),
        Text(
          'ABRIR CONFIGURAÇÕES',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: TClubColors.redPrincipal,
          ),
        ),
      ]),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  ETAPA DE CAPTURA
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCapturaStep() {
    return Stack(children: [
      Positioned.fill(child: _buildViewfinder()),
      Positioned(
        top: 0, left: 0, right: 0, height: 180,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 0, left: 0, right: 0, height: 280,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xDD000000), Colors.transparent],
            ),
          ),
        ),
      ),
      _neonLine(),
      SafeArea(child: Column(children: [
        _buildTopBarCaptura(),
        Expanded(child: _buildModeContent()),
        _buildModoSelector(),
        _buildBottomCaptura(),
        const SizedBox(height: 20),
      ])),
    ]);
  }

  Widget _buildViewfinder() {
    if (_modoAtual == _StoryMode.camera || _modoAtual == _StoryMode.video) {
      if (_cameraReady && _cameraCtrl != null) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraCtrl!.value.previewSize!.height,
              height: _cameraCtrl!.value.previewSize!.width,
              child: CameraPreview(_cameraCtrl!),
            ),
          ),
        );
      }
      return Container(
        color: TClubColors.bg,
        child: Center(
          child: SizedBox(
            width: 32, height: 32,
            child: CircularProgressIndicator(
              color: TClubColors.redPrincipal,
              strokeWidth: 1.5,
            ),
          ),
        ),
      );
    }
    if (_modoAtual == _StoryMode.texto) {
      final colors = _fundoGradients[_fundoSelecionado]!;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomPaint(
          painter: _ParticlePainter(color: Colors.white, seed: 42, count: 60),
        ),
      );
    }
    return Container(color: TClubColors.bg);
  }

  Widget _buildTopBarCaptura() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        _IconBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
        const Spacer(),
        _storyLabel(),
        const Spacer(),
        if (_modoAtual == _StoryMode.camera || _modoAtual == _StoryMode.video)
          Row(children: [
            if (_modoAtual == _StoryMode.camera)
              _IconBtn(
                icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                onTap: _toggleFlash,
                active: _flashOn,
              ),
            const SizedBox(width: 6),
            _IconBtn(icon: Icons.cameraswitch_outlined, onTap: _virarCamera),
          ])
        else
          const SizedBox(width: 88),
      ]),
    );
  }

  Widget _buildModeContent() {
    if (_modoAtual == _StoryMode.texto) return _buildModoTexto();
    if (_modoAtual == _StoryMode.emoji) return _buildModoEmoji();
    return const SizedBox.shrink();
  }

  Widget _buildModoTexto() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(_textFocus),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _Fundo.values.map((f) {
                  final sel = _fundoSelecionado == f;
                  final colors = _fundoGradients[f]!;
                  return GestureDetector(
                    onTap: () => setState(() => _fundoSelecionado = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32, height: 32,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: sel ? TClubColors.redPrincipal : TClubColors.border,
                          width: sel ? 2 : 0.8,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: TClubColors.bgCard,
                border: Border.all(
                  color: _textFocus.hasFocus ? TClubColors.redPrincipal : TClubColors.borderMid,
                  width: _textFocus.hasFocus ? 1.5 : 0.8,
                ),
              ),
              child: TextField(
                controller: _textCtrl,
                focusNode: _textFocus,
                maxLines: 5,
                maxLength: 200,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontFamily: _estiloTexto == _TextStyle.display
                      ? TClubTypography.displayFont
                      : TClubTypography.bodyFont,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _estiloTexto == _TextStyle.branco
                      ? TClubColors.textoPrincipal
                      : _estiloTexto == _TextStyle.rosa
                          ? TClubColors.redPrincipal
                          : TClubColors.redDeep,
                  letterSpacing: _estiloTexto == _TextStyle.display ? 3 : 0.5,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'O que está rolando?',
                  hintStyle: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 20,
                    color: TClubColors.textoMuted,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _TextStyle.values.map((s) {
                final sel = _estiloTexto == s;
                return GestureDetector(
                  onTap: () => setState(() => _estiloTexto = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? TClubColors.redPale : TClubColors.bgCard,
                      border: Border.all(
                        color: sel ? TClubColors.redPrincipal : TClubColors.borderMid,
                        width: sel ? 1.2 : 0.5,
                      ),
                    ),
                    child: Text(
                      s.label,
                      style: TextStyle(
                        fontFamily: s == _TextStyle.display
                            ? TClubTypography.displayFont
                            : TClubTypography.bodyFont,
                        fontSize: s == _TextStyle.display ? 10 : 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: s == _TextStyle.display ? 2 : 1.5,
                        color: sel ? TClubColors.redPrincipal : TClubColors.textoMuted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModoEmoji() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _emojiSelecionado != null
                ? Text(
                    _emojiSelecionado!,
                    key: ValueKey(_emojiSelecionado),
                    style: const TextStyle(fontSize: 110),
                  )
                : Column(key: const ValueKey('ph'), children: [
                    Icon(Icons.emoji_emotions_outlined,
                        color: TClubColors.border, size: 60),
                    const SizedBox(height: 10),
                    Text(
                      'ESCOLHA UM EMOJI',
                      style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                        color: TClubColors.textoMuted,
                      ),
                    ),
                  ]),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TClubColors.bgCard,
              border: Border.all(color: TClubColors.borderMid, width: 0.8),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _emojis.length,
              itemBuilder: (_, i) {
                final emoji = _emojis[i];
                final sel = _emojiSelecionado == emoji;
                return GestureDetector(
                  onTap: () {
                    setState(() => _emojiSelecionado = sel ? null : emoji);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    decoration: BoxDecoration(
                      color: sel ? TClubColors.redPale : TClubColors.bg,
                      border: Border.all(
                        color: sel ? TClubColors.redPrincipal : TClubColors.border,
                        width: sel ? 1.5 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Seletor de modo ───────────────────────────────────────────────────────
  Widget _buildModoSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _StoryMode.values.map((m) {
          final sel = _modoAtual == m;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _modoAtual = m);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? TClubColors.redPale : TClubColors.bg.withOpacity(0.85),
                  border: Border.all(
                    color: sel ? TClubColors.redPrincipal : TClubColors.border,
                    width: sel ? 1.2 : 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      m.icon,
                      size: 14,
                      color: sel ? TClubColors.redPrincipal : TClubColors.textoMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TClubTypography.bodyFont,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: sel ? TClubColors.redPrincipal : TClubColors.textoMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomCaptura() {
    if (_modoAtual == _StoryMode.texto) {
      final ok = _textCtrl.text.trim().isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: GestureDetector(
          onTap: ok ? _confirmarTexto : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: ok ? TClubColors.redPrincipal : TClubColors.bgCard,
              border: Border.all(
                color: ok ? TClubColors.redPrincipal : TClubColors.borderMid,
                width: 0.8,
              ),
              boxShadow: ok ? TClubGlow.redPrincipal(blur: 20) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CONTINUAR',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: ok ? TClubColors.branco : TClubColors.textoMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: ok ? TClubColors.branco : TClubColors.textoMuted,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_modoAtual == _StoryMode.emoji) {
      final ok = _emojiSelecionado != null;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: GestureDetector(
          onTap: ok ? _confirmarEmoji : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: ok ? TClubColors.redPrincipal : TClubColors.bgCard,
              border: Border.all(
                color: ok ? TClubColors.redPrincipal : TClubColors.borderMid,
                width: 0.8,
              ),
              boxShadow: ok ? TClubGlow.redPrincipal(blur: 20) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_emojiSelecionado != null) ...[
                  Text(_emojiSelecionado!, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                ],
                Text(
                  'USAR EMOJI',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: ok ? TClubColors.branco : TClubColors.textoMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_modoAtual == _StoryMode.camera) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickGaleria,
              child: _CameraActionBtn(icon: Icons.photo_library_outlined),
            ),
            GestureDetector(
              onTap: _tirarFoto,
              child: ScaleTransition(
                scale: _captureAnim,
                child: Stack(alignment: Alignment.center, children: [
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TClubColors.redPrincipal.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 74, height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TClubColors.branco,
                      boxShadow: TClubGlow.redPrincipal(blur: 16, spread: 2),
                    ),
                  ),
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: TClubColors.redPrincipal.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            GestureDetector(
              onTap: _virarCamera,
              child: _CameraActionBtn(icon: Icons.cameraswitch_outlined),
            ),
          ],
        ),
      );
    }
    // Modo vídeo — usa câmera nativa via ImagePicker
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickGaleriaVideo,
                child: _CameraActionBtn(icon: Icons.video_library_outlined),
              ),
              GestureDetector(
                onTap: _gravarVideoCamera,
                child: ScaleTransition(
                  scale: _captureAnim,
                  child: Stack(alignment: Alignment.center, children: [
                    ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: TClubColors.redPrincipal.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 74, height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TClubColors.branco,
                        boxShadow: TClubGlow.branco(blur: 16),
                      ),
                    ),
                    Icon(Icons.videocam_rounded,
                        color: TClubColors.redPrincipal, size: 32),
                  ]),
                ),
              ),
              GestureDetector(
                onTap: _virarCamera,
                child: _CameraActionBtn(icon: Icons.cameraswitch_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Toque para abrir câmera · máx $_maxVideoSeconds seg',
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: TClubColors.textoMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ETAPA DE EDIÇÃO
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEdicaoStep() {
    return LayoutBuilder(builder: (context, constraints) {
      final sw = constraints.maxWidth;
      final sh = constraints.maxHeight;
      _editorW = sw;
      _editorH = sh;

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => setState(() {
          _overlayAtivo = null;
          _toolTextOpen = false;
          _toolEmojiOpen = false;
        }),
        child: Stack(children: [
          Positioned.fill(child: _buildEdicaoPreview()),
          Positioned(
            top: 0, left: 0, right: 0, height: 160,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xBB000000), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0, height: 200,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),
          if (_modoAtual == _StoryMode.texto && _textoCentral.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _textoCentral,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _estiloTexto == _TextStyle.display
                            ? TClubTypography.displayFont
                            : TClubTypography.bodyFont,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _estiloTexto == _TextStyle.branco
                            ? Colors.white
                            : _estiloTexto == _TextStyle.rosa
                                ? TClubColors.redClaro
                                : Colors.black,
                        letterSpacing: _estiloTexto == _TextStyle.display ? 3 : 0.5,
                        height: 1.35,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 2)),
                          Shadow(color: Colors.black54, blurRadius: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_modoAtual == _StoryMode.emoji && _emojiSelecionado != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    _emojiSelecionado!,
                    style: const TextStyle(
                      fontSize: 160,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
          ..._overlays.asMap().entries
              .map((e) => _buildOverlayWidget(e.key, e.value, sw, sh)),
          _neonLine(),
          if (_publicando) _buildPublishOverlay(),
          SafeArea(
            child: AnimatedBuilder(
              animation: _toolbarAnim,
              builder: (_, child) => Opacity(
                opacity: _toolbarAnim.value,
                child: Transform.translate(
                  offset: Offset(0, -8 * (1 - _toolbarAnim.value)),
                  child: child!,
                ),
              ),
              child: Column(children: [
                _buildTopBarEdicao(),
                Expanded(child: _buildEdicaoMiddle()),
                _buildBottomEdicao(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ]),
      );
    });
  }

  Widget _buildEdicaoPreview() {
    switch (_modoAtual) {
      case _StoryMode.camera:
        if (_midia != null) {
          return Container(
            color: Colors.black,
            child: LayoutBuilder(builder: (ctx, constraints) {
              final px = _ajusteOffset.dx * constraints.maxWidth;
              final py = _ajusteOffset.dy * constraints.maxHeight;
              return ClipRect(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(px, py)
                    ..rotateZ(_ajusteRotation)
                    ..scale(_ajusteScale),
                  child: Image.file(
                    _midia!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              );
            }),
          );
        }
        return Container(color: Colors.black);
      case _StoryMode.video:
        if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
          return GestureDetector(
            onTap: _toggleVideoPlay,
            child: Container(
              color: Colors.black,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoCtrl!.value.size.width,
                      height: _videoCtrl!.value.size.height,
                      child: VideoPlayer(_videoCtrl!),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _videoPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TClubColors.bg.withOpacity(0.85),
                      border: Border.all(color: TClubColors.redPrincipal, width: 1.5),
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                        color: TClubColors.redPrincipal, size: 32),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _StoryVideoProgressBar(controller: _videoCtrl!),
                ),
                Positioned(
                  bottom: 8, left: 10,
                  child: _buildVideoDuracaoBadge(),
                ),
              ]),
            ),
          );
        }
        return Container(color: Colors.black);
      case _StoryMode.texto:
        final colors = _fundoGradients[_fundoSelecionado]!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CustomPaint(
            painter: _ParticlePainter(color: Colors.white, seed: 42, count: 60),
          ),
        );
      case _StoryMode.emoji:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D0010), Color(0xFF1A0020)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CustomPaint(
            painter: _ParticlePainter(color: Colors.white, seed: 99, count: 40),
          ),
        );
    }
  }

  Widget _buildVideoDuracaoBadge() {
    if (_videoDuration == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TClubColors.bg.withOpacity(0.88),
        border: Border.all(color: TClubColors.borderMid, width: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.videocam_outlined, size: 11, color: TClubColors.redPrincipal),
        const SizedBox(width: 4),
        Text(
          '${_videoDuration!.inSeconds}s',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: TClubColors.textoPrincipal,
          ),
        ),
      ]),
    );
  }

  Widget _buildPublishOverlay() {
    final label = switch (_publishStep) {
      _PublishStep.uploadingMedia => 'ENVIANDO VÍDEO...',
      _PublishStep.salvando => 'PUBLICANDO...',
      _ => 'AGUARDE...',
    };
    return Positioned.fill(
      child: Container(
        color: TClubColors.bg.withOpacity(0.80),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 72, height: 72,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: _publishStep == _PublishStep.uploadingMedia
                      ? _uploadProgress
                      : null,
                  color: TClubColors.redPrincipal,
                  backgroundColor: TClubColors.redPale,
                  strokeWidth: 3,
                ),
                if (_publishStep == _PublishStep.uploadingMedia)
                  Text(
                    '${(_uploadProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: TClubColors.textoPrincipal,
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: TClubColors.textoSecundario,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildOverlayWidget(int index, _Overlay ov, double sw, double sh) {
    final isAtivo = _overlayAtivo == index;
    const halfText = 80.0;
    const halfEmoji = 32.0;
    final halfW = ov.isEmoji ? halfEmoji : halfText;
    final halfH = ov.isEmoji ? halfEmoji : 22.0;

    return Positioned(
      left: ov.dx - halfW,
      top: ov.dy - halfH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _overlayAtivo = isAtivo ? null : index;
            _toolTextOpen = false;
            _toolEmojiOpen = false;
          });
          HapticFeedback.selectionClick();
        },
        onPanStart: (_) => setState(() => _overlayAtivo = index),
        onPanUpdate: (d) => setState(() {
          ov.dx = (ov.dx + d.delta.dx).clamp(24.0, sw - 24.0);
          ov.dy = (ov.dy + d.delta.dy).clamp(24.0, sh - 24.0);
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: ov.isEmoji
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: ov.isEmoji
                ? Colors.transparent
                : TClubColors.bg.withOpacity(isAtivo ? 0.90 : 0.75),
            borderRadius: BorderRadius.circular(6),
            border: isAtivo
                ? Border.all(color: TClubColors.redPrincipal, width: 1.8)
                : (ov.isEmoji
                    ? null
                    : Border.all(color: TClubColors.borderMid, width: 0.8)),
            boxShadow: isAtivo ? TClubGlow.redSubtle() : null,
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            ov.isEmoji
                ? Text(
                    ov.conteudo,
                    style: TextStyle(
                      fontSize: 56 * ov.scale,
                      shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  )
                : Text(
                    ov.conteudo,
                    style: TextStyle(
                      fontFamily: TClubTypography.bodyFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TClubColors.textoPrincipal,
                      letterSpacing: 0.5,
                    ),
                  ),
            if (isAtivo)
              Positioned(
                top: -14, right: -14,
                child: GestureDetector(
                  onTap: () => _removerOverlay(index),
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TClubColors.error,
                      border: Border.all(color: TClubColors.branco, width: 2),
                      boxShadow: TClubGlow.error(blur: 4),
                    ),
                    child: Icon(Icons.close, color: TClubColors.branco, size: 13),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTopBarEdicao() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(children: [
        _IconBtn(
          icon: Icons.arrow_back_ios_new,
          onTap: _publicando ? () {} : _voltarCaptura,
        ),
        const Spacer(),
        if (!_publicando)
          Row(children: [
            _ToolBtn(
              icon: Icons.text_fields_rounded,
              label: 'Aa',
              active: _toolTextOpen,
              onTap: () {
                setState(() {
                  _toolTextOpen = !_toolTextOpen;
                  _toolEmojiOpen = false;
                  _overlayAtivo = null;
                });
                if (_toolTextOpen) {
                  Future.delayed(const Duration(milliseconds: 80),
                      () => FocusScope.of(context).requestFocus(_textFocus));
                }
              },
            ),
            const SizedBox(width: 8),
            _ToolBtn(
              icon: Icons.emoji_emotions_outlined,
              active: _toolEmojiOpen,
              onTap: () => setState(() {
                _toolEmojiOpen = !_toolEmojiOpen;
                _toolTextOpen = false;
                _overlayAtivo = null;
                FocusScope.of(context).unfocus();
              }),
            ),
          ]),
      ]),
    );
  }

  Widget _buildEdicaoMiddle() {
    if (_publicando) return const SizedBox.shrink();
    if (_toolTextOpen) return _buildPainelTexto();
    if (_toolEmojiOpen) return _buildPainelEmoji();
    if (_overlays.isEmpty && _textoCentral.isEmpty && _emojiSelecionado == null) {
      return Center(
        child: Text(
          'Toque em Aa ou 😊 para adicionar elementos',
          style: TextStyle(
            fontFamily: TClubTypography.bodyFont,
            fontSize: 11,
            color: TClubColors.textoMuted,
            letterSpacing: 1,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPainelTexto() {
    return GestureDetector(
      onTap: () {},
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TClubColors.bgCard,
            border: Border.all(color: TClubColors.borderMid, width: 0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: TClubGlow.card(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _TextStyle.values.map((s) {
                  final sel = _estiloTexto == s;
                  return GestureDetector(
                    onTap: () => setState(() => _estiloTexto = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? TClubColors.redPale : TClubColors.bg,
                        border: Border.all(
                          color: sel ? TClubColors.redPrincipal : TClubColors.borderMid,
                          width: sel ? 1.2 : 0.5,
                        ),
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontFamily: s == _TextStyle.display
                              ? TClubTypography.displayFont
                              : TClubTypography.bodyFont,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: s == _TextStyle.display ? 2 : 1.5,
                          color: sel ? TClubColors.redPrincipal : TClubColors.textoMuted,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textCtrl,
                focusNode: _textFocus,
                maxLines: 3,
                maxLength: 120,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontFamily: _estiloTexto == _TextStyle.display
                      ? TClubTypography.displayFont
                      : TClubTypography.bodyFont,
                  fontSize: 18,
                  color: _estiloTexto == _TextStyle.branco
                      ? TClubColors.textoPrincipal
                      : _estiloTexto == _TextStyle.rosa
                          ? TClubColors.redPrincipal
                          : TClubColors.redDeep,
                  fontWeight: FontWeight.w700,
                  letterSpacing: _estiloTexto == _TextStyle.display ? 2 : 0.3,
                ),
                decoration: InputDecoration(
                  hintText: 'Digite aqui...',
                  hintStyle: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 16,
                    color: TClubColors.textoMuted,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _confirmarTexto,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _textCtrl.text.trim().isNotEmpty
                        ? TClubColors.redPrincipal
                        : TClubColors.redPale,
                    border: Border.all(color: TClubColors.redPrincipal, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_rounded, color: TClubColors.branco, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'ADICIONAR AO STORY',
                        style: TextStyle(
                          fontFamily: TClubTypography.bodyFont,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: TClubColors.branco,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPainelEmoji() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TClubColors.bgCard,
          border: Border.all(color: TClubColors.borderMid, width: 0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: TClubGlow.card(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOQUE PARA ADICIONAR',
                  style: TextStyle(
                    fontFamily: TClubTypography.bodyFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: TClubColors.textoMuted,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _toolEmojiOpen = false),
                  child: Icon(Icons.close, color: TClubColors.textoMuted, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _emojis.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _adicionarEmojiOverlay(_emojis[i]),
                child: Container(
                  decoration: BoxDecoration(
                    color: TClubColors.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: TClubColors.border, width: 0.5),
                  ),
                  child: Center(
                    child: Text(_emojis[i], style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barra inferior de edição ──────────────────────────────────────────────
  Widget _buildBottomEdicao() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FIX: botões de visibilidade envolvidos em Flexible para evitar
          // RenderFlex overflow de 11px em telas estreitas.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _VisibBtn(
                  label: 'PÚBLICO',
                  icon: Icons.public_rounded,
                  value: 'publico',
                  current: _visibilidade,
                  onTap: () => setState(() => _visibilidade = 'publico'),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _VisibBtn(
                  label: 'SEGUIDORES',
                  icon: Icons.people_outline_rounded,
                  value: 'seguidores',
                  current: _visibilidade,
                  onTap: () => setState(() => _visibilidade = 'seguidores'),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _VisibBtn(
                  label: 'VIP',
                  icon: Icons.star_border_rounded,
                  value: 'vip',
                  current: _visibilidade,
                  onTap: () => setState(() => _visibilidade = 'vip'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            GestureDetector(
              onTap: _publicando ? null : _voltarCaptura,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52, width: 52,
                decoration: BoxDecoration(
                  color: _publicando ? TClubColors.bgCard.withOpacity(0.5) : TClubColors.bgCard,
                  border: Border.all(
                    color: _publicando ? TClubColors.border : TClubColors.borderMid,
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: _publicando
                      ? TClubColors.textoMuted.withOpacity(0.4)
                      : TClubColors.textoMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _publicando ? null : _publicar,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    color: _publishStep == _PublishStep.erro
                        ? TClubColors.error
                        : TClubColors.redPrincipal,
                    border: Border.all(
                        color: _publishStep == _PublishStep.erro
                            ? TClubColors.error
                            : TClubColors.redPrincipal,
                        width: 1),
                    boxShadow: _publicando
                        ? null
                        : (_publishStep == _PublishStep.erro
                            ? TClubGlow.error(blur: 20, spread: 2)
                            : TClubGlow.redPrincipal(blur: 20, spread: 2)),
                  ),
                  child: Center(
                    child: _publicando
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: TClubColors.branco, strokeWidth: 2,
                            ),
                          )
                        : _publishStep == _PublishStep.erro
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.error_outline_rounded,
                                      color: TClubColors.branco, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'TENTAR NOVAMENTE',
                                    style: TextStyle(
                                      fontFamily: TClubTypography.bodyFont,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: TClubColors.branco,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.auto_awesome_rounded,
                                      color: TClubColors.branco, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'PUBLICAR STORY',
                                    style: TextStyle(
                                      fontFamily: TClubTypography.bodyFont,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.5,
                                      color: TClubColors.branco,
                                    ),
                                  ),
                                ],
                              ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _publicando
                  ? null
                  : () => _snack('Enviar para amigos — em breve!'),
              child: Container(
                height: 52, width: 52,
                decoration: BoxDecoration(
                  color: _publicando ? TClubColors.bgCard.withOpacity(0.5) : TClubColors.bgCard,
                  border: Border.all(
                    color: _publicando ? TClubColors.border : TClubColors.borderMid,
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _publicando
                      ? TClubColors.textoMuted.withOpacity(0.4)
                      : TClubColors.textoMuted,
                  size: 20,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _neonLine() => Positioned(
    top: 0, left: 0, right: 0,
    child: Container(
      height: 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [
          TClubColors.redDeep,
          TClubColors.redPrincipal,
          TClubColors.redClaro,
          TClubColors.redPrincipal,
          TClubColors.redDeep,
        ]),
      ),
    ),
  );

  Widget _storyLabel() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: TClubColors.bgCard,
      border: Border.all(color: TClubColors.borderMid, width: 0.8),
    ),
    child: Text(
      'STORY',
      style: TextStyle(
        fontFamily: TClubTypography.displayFont,
        fontSize: 14,
        letterSpacing: 5,
        color: TClubColors.redPrincipal,
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _CameraActionBtn extends StatelessWidget {
  final IconData icon;
  const _CameraActionBtn({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(
      color: TClubColors.bgCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: TClubColors.borderMid, width: 0.8),
      boxShadow: TClubGlow.card(),
    ),
    child: Icon(icon, color: TClubColors.textoSecundario, size: 22),
  );
}

class _StoryVideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _StoryVideoProgressBar({required this.controller});
  @override
  State<_StoryVideoProgressBar> createState() => _StoryVideoProgressBarState();
}

class _StoryVideoProgressBarState extends State<_StoryVideoProgressBar> {
  @override
  void initState() { super.initState(); widget.controller.addListener(_u); }
  @override
  void dispose() { widget.controller.removeListener(_u); super.dispose(); }
  void _u() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final pos   = widget.controller.value.position.inMilliseconds.toDouble();
    final total = widget.controller.value.duration.inMilliseconds.toDouble();
    final pct   = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      height: 3,
      color: TClubColors.border,
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

class _PermissaoCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descricao;
  final _PermissaoStatus status;
  const _PermissaoCard({
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.status,
  });

  Color get _cor => switch (status) {
    _PermissaoStatus.concedido         => const Color(0xFF4CAF50),
    _PermissaoStatus.negadoPermanente  => TClubColors.error,
    _PermissaoStatus.verificando       => TClubColors.border,
    _PermissaoStatus.pendente          => TClubColors.textoMuted,
  };

  IconData get _ic => switch (status) {
    _PermissaoStatus.concedido         => Icons.check_circle_rounded,
    _PermissaoStatus.negadoPermanente  => Icons.cancel_rounded,
    _PermissaoStatus.verificando       => Icons.hourglass_empty_rounded,
    _PermissaoStatus.pendente          => Icons.radio_button_unchecked_rounded,
  };

  String get _lb => switch (status) {
    _PermissaoStatus.concedido         => 'CONCEDIDO',
    _PermissaoStatus.negadoPermanente  => 'BLOQUEADO',
    _PermissaoStatus.verificando       => 'VERIFICANDO',
    _PermissaoStatus.pendente          => 'PENDENTE',
  };

  @override
  Widget build(BuildContext context) {
    final ok = status == _PermissaoStatus.concedido;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFF4CAF50).withOpacity(0.07) : TClubColors.bgCard,
        border: Border.all(
          color: _cor.withOpacity(ok ? 0.4 : 0.2),
          width: ok ? 1 : 0.7,
        ),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _cor.withOpacity(0.1),
            border: Border.all(color: _cor.withOpacity(0.3), width: 0.8),
          ),
          child: Icon(icon, color: _cor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: TClubColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                descricao,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 10,
                  letterSpacing: 0.3,
                  color: TClubColors.textoMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_ic, color: _cor, size: 14),
          const SizedBox(width: 4),
          Text(
            _lb,
            style: TextStyle(
              fontFamily: TClubTypography.bodyFont,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: _cor,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _VisibBtn extends StatelessWidget {
  final String label, value, current;
  final IconData icon;
  final VoidCallback onTap;
  const _VisibBtn({
    required this.label,
    required this.icon,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    final isVip  = value == 'vip';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        // Padding horizontal reduzido para caber em telas estreitas
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (isVip ? const Color(0xFFFFF8E1) : TClubColors.redPale)
              : TClubColors.bgCard,
          border: Border.all(
            color: active
                ? (isVip ? const Color(0xFFD4AF37) : TClubColors.redPrincipal)
                : TClubColors.borderMid,
            width: active ? 1 : 0.6,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            icon,
            size: 11,
            color: active
                ? (isVip ? const Color(0xFFD4AF37) : TClubColors.redPrincipal)
                : TClubColors.textoMuted,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TClubTypography.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: active
                    ? (isVip ? const Color(0xFFD4AF37) : TClubColors.redPrincipal)
                    : TClubColors.textoMuted,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

enum _StoryMode {
  camera(Icons.photo_camera_outlined, 'CÂMERA'),
  texto(Icons.text_fields_rounded, 'TEXTO'),
  emoji(Icons.emoji_emotions_outlined, 'EMOJI'),
  video(Icons.videocam_outlined, 'VÍDEO');

  final IconData icon;
  final String label;
  const _StoryMode(this.icon, this.label);
}

enum _StoryStep { captura, edicao }

enum _TextStyle {
  branco('BRANCO'), rosa('ROSA'), display('DISPLAY');
  final String label;
  const _TextStyle(this.label);
}

enum _Fundo { escuro, rosaFogo, roxo, ouro, azulNoite, verde }

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _IconBtn({required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? TClubColors.redPale : TClubColors.bgCard,
        border: Border.all(
          color: active ? TClubColors.redPrincipal : TClubColors.borderMid,
          width: active ? 1.2 : 0.8,
        ),
        boxShadow: active ? TClubGlow.redSubtle() : TClubGlow.card(blur: 6),
      ),
      child: Icon(
        icon,
        color: active ? TClubColors.redPrincipal : TClubColors.textoSecundario,
        size: 18,
      ),
    ),
  );
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool active;
  const _ToolBtn({
    required this.icon,
    required this.onTap,
    this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: active ? TClubColors.redPale : TClubColors.bgCard,
        border: Border.all(
          color: active ? TClubColors.redPrincipal : TClubColors.borderMid,
          width: active ? 1.5 : 0.8,
        ),
        boxShadow: active ? TClubGlow.redPrincipal(blur: 10) : TClubGlow.card(blur: 6),
      ),
      child: label != null
          ? Center(
              child: Text(
                label!,
                style: TextStyle(
                  fontFamily: TClubTypography.bodyFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? TClubColors.redPrincipal : TClubColors.textoSecundario,
                ),
              ),
            )
          : Icon(
              icon,
              color: active ? TClubColors.redPrincipal : TClubColors.textoSecundario,
              size: 20,
            ),
    ),
  );
}

class _ParticlePainter extends CustomPainter {
  final Color color;
  final int seed;
  final int count;
  const _ParticlePainter({required this.color, required this.seed, required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final p = Paint()..color = color.withOpacity(0.04);
    for (int i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 2.5 + 0.5,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter o) => false;
}

