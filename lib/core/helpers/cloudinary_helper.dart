// lib/core/utils/cloudinary_helper.dart
//
// NÍVEL 2.3 — Transformações Cloudinary on-the-fly.
// Reduz ~90% de bandwidth de imagem sem nenhuma mudança no backend.
// Todas as imagens continuam no mesmo Cloudinary, apenas a URL de entrega muda.

class CloudinaryHelper {
  CloudinaryHelper._();

  /// Otimiza URL de imagem Cloudinary: redimensiona, converte pra WebP, auto-qualidade.
  /// Se a URL não for do Cloudinary, retorna sem modificação.
  static String optimizeImageUrl(String url, {int width = 400, int height = 400}) {
    if (!url.contains('cloudinary.com') || !url.contains('/upload/')) return url;
    return url.replaceFirst(
      '/upload/',
      '/upload/c_fill,w_$width,h_$height,q_auto,f_auto/',
    );
  }

  /// Versão para avatares — quadrado pequeno com detecção de rosto.
  /// Avatar de 200KB original → ~8KB otimizado.
  static String avatarUrl(String url, {int size = 150}) {
    if (!url.contains('cloudinary.com') || !url.contains('/upload/')) return url;
    return url.replaceFirst(
      '/upload/',
      '/upload/c_fill,w_$size,h_$size,g_face,q_auto,f_auto/',
    );
  }

  /// Versão para banners de festa / imagem de post em grid.
  static String bannerUrl(String url, {int width = 600, int height = 340}) {
    if (!url.contains('cloudinary.com') || !url.contains('/upload/')) return url;
    return url.replaceFirst(
      '/upload/',
      '/upload/c_fill,w_$width,h_$height,q_auto,f_auto/',
    );
  }

  /// Versão para imagem fullscreen — maior qualidade, largura de tela.
  static String fullScreenUrl(String url, {int width = 1080}) {
    if (!url.contains('cloudinary.com') || !url.contains('/upload/')) return url;
    return url.replaceFirst(
      '/upload/',
      '/upload/c_limit,w_$width,q_auto,f_auto/',
    );
  }

  /// Thumbnail de vídeo para grid de perfil — quadrado 1:1, cobre o card exatamente.
  /// width e height iguais garantem que c_fill corta centralizado sem deixar espaços.
  static String videoThumbnail(String url, {int width = 400, int? height}) {
    if (!url.contains('cloudinary.com') || !url.contains('/upload/')) return url;
    final thumbUrl = url.replaceAll(RegExp(r'\.(mp4|mov|avi|webm)$', caseSensitive: false), '.jpg');
    final h = height ?? width; // padrão: quadrado igual ao width
    return thumbUrl.replaceFirst(
      '/upload/',
      '/upload/c_fill,w_$width,h_$h,g_auto,q_auto,f_auto/',
    );
  }

  /// Story — formato vertical otimizado.
  static String storyUrl(String url, {int width = 720, int height = 1280}) {
    if (!url.contains('cloudinary.com') || !url.contains('/upload/')) return url;
    return url.replaceFirst(
      '/upload/',
      '/upload/c_fill,w_$width,h_$height,q_auto,f_auto/',
    );
  }
}