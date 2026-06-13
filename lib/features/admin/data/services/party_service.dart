// lib/services/services_administrative/party_service.dart
//
// OTIMIZAÇÃO NÍVEL 1:
//   • fetchFestas() — usa orderByChild('data_fim').startAt(now) para buscar
//     apenas festas ativas (data_fim no futuro) em vez de baixar TODAS e filtrar.
//   • fetchFestasArquivadas() — usa endBefore(now).limitToLast(limit) para
//     buscar apenas festas vencidas.
//
//   Requisito: índice em Festas/.indexOn: ["data_fim"]

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:tabuapp/features/feed/data/services/cloudinary_cleanup_helper.dart';
import 'package:tabuapp/features/party/data/models/party_model.dart';

class PartyService {
  PartyService._();
  static final PartyService instance = PartyService._();

  final _db = FirebaseDatabase.instance;

  DatabaseReference get _festasRef => _db.ref('Festas');
  DatabaseReference _festaRef(String id) => _festasRef.child(id);

  // ══════════════════════════════════════════════════════════════════════════
  //  CRIAR
  //
  //  Apenas grava em Festas/{id}. O trigger onValueCreated da CF
  //  notificarNovaFesta é disparado automaticamente e faz o fan-out
  //  para todos os seguidores usando Followers/{creatorUid}.
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> createFesta({
    required String creatorId,
    required String creatorName,
    String? creatorAvatar,
    required String nome,
    required String descricao,
    String? local,
    String? bairro,
    String? city,
    String? state,
    double? latitude,
    double? longitude,
    required DateTime dataInicio,
    required DateTime dataFim,
    String? bannerUrl,
  }) async {
    final ref = _festasRef.push();

    // Monta o payload manualmente para usar ServerValue.timestamp em created_at.
    // Isso evita PERMISSION_DENIED por dessincronização de relógio entre o
    // dispositivo e o servidor Firebase (rule: created_at <= now + 120000).
    final payload = <String, dynamic>{
      'creator_id': creatorId,
      'creator_uid': creatorId, // rule de write aceita qualquer um dos dois
      'creator_name': creatorName,
      if (creatorAvatar != null && creatorAvatar.isNotEmpty)
        'creator_avatar': creatorAvatar,
      'nome': nome,
      'name': nome,
      'descricao': descricao,
      if (local != null && local.trim().isNotEmpty) 'local': local,
      if (bairro != null && bairro.trim().isNotEmpty) 'bairro': bairro,
      if (city != null && city.trim().isNotEmpty) 'city': city,
      if (state != null && state.trim().isNotEmpty) 'state': state,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'data_inicio': dataInicio.millisecondsSinceEpoch,
      'data_fim': dataFim.millisecondsSinceEpoch,
      if (bannerUrl != null && bannerUrl.isNotEmpty) 'banner_url': bannerUrl,
      'created_at':
          ServerValue.timestamp, // ← timestamp do servidor, nunca falha
      'status': 'ativa',
    };

    await ref.set(payload);
    return ref.key!;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUSCAR (só ativas)
  //
  //  ANTES: _festasRef.get() baixava TODAS as festas e filtrava client-side.
  //  AGORA: query filtrada por data_fim > agora (só festas no futuro).
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<PartyModel>> fetchFestas({int limit = 20}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final snap = await _festasRef.orderByChild('data_fim').startAt(now).get();

    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <PartyModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final festa = PartyModel.fromMap(
          entry.key as String,
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
        if (!festa.isArquivada) list.add(festa);
      } catch (e) {
        debugPrint('fetchFestas error ${entry.key}: $e');
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  Future<List<PartyModel>> fetchFestasArquivadas({int limit = 50}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final snap = await _festasRef
        .orderByChild('data_fim')
        .endBefore(now)
        .limitToLast(limit)
        .get();

    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <PartyModel>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        final festa = PartyModel.fromMap(
          entry.key as String,
          Map<dynamic, dynamic>.from(entry.value as Map),
        );
        list.add(festa);
      } catch (_) {}
    }

    list.sort((a, b) => b.dataFim.compareTo(a.dataFim));
    return list.take(limit).toList();
  }

  /// Arquiva manualmente uma festa.
  Future<void> arquivarFesta(String festaId) async {
    await _festaRef(festaId).update({'status': 'arquivada'});
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRESENÇA
  // ══════════════════════════════════════════════════════════════════════════

  Future<FestaPresenca> getPresenca(String festaId, String uid) async {
    final snap = await _db.ref('Festas/$festaId/presenca/$uid').get();
    if (!snap.exists) return FestaPresenca.nenhuma;
    final v = snap.value as String?;
    if (v == 'confirmado') return FestaPresenca.confirmado;
    if (v == 'interessado') return FestaPresenca.interessado;
    return FestaPresenca.nenhuma;
  }

  /// Contadores gerenciados pela CF onFestaPresencaChanged — não mexer aqui.
  Future<FestaPresenca> togglePresenca(
    String festaId,
    String uid,
    FestaPresenca atual,
  ) async {
    final ref = _db.ref('Festas/$festaId/presenca/$uid');
    switch (atual) {
      case FestaPresenca.nenhuma:
        await ref.set('interessado');
        return FestaPresenca.interessado;
      case FestaPresenca.interessado:
        await ref.set('confirmado');
        return FestaPresenca.confirmado;
      case FestaPresenca.confirmado:
        await ref.remove();
        return FestaPresenca.nenhuma;
    }
  }

  /// Aplica estado diretamente sem intermediários — UMA escrita, UMA CF.
  Future<void> setPresenca(
    String festaId,
    String uid,
    FestaPresenca de,
    FestaPresenca para,
  ) async {
    if (de == para) return;
    final ref = _db.ref('Festas/$festaId/presenca/$uid');
    if (para == FestaPresenca.nenhuma) {
      await ref.remove();
    } else {
      await ref.set(
          para == FestaPresenca.interessado ? 'interessado' : 'confirmado');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMENTÁRIOS
  // ══════════════════════════════════════════════════════════════════════════

  // Para "ver mais", passe o created_at do mais antigo já carregado em [endBefore].
  Future<List<Map<String, dynamic>>> fetchComentarios(
    String festaId, {
    int limit = 20,
    int? endBefore, // created_at do comentário mais antigo já carregado
  }) async {
    var query = _db
        .ref('Festas/$festaId/comentarios')
        .orderByChild('created_at')
        .limitToLast(limit);

    if (endBefore != null) {
      query = _db
          .ref('Festas/$festaId/comentarios')
          .orderByChild('created_at')
          .endBefore(endBefore)
          .limitToLast(limit);
    }

    final snap = await query.get();
    if (!snap.exists || snap.value == null) return [];

    final raw = Map<dynamic, dynamic>.from(snap.value as Map);
    final list = <Map<String, dynamic>>[];

    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      final data = Map<String, dynamic>.from(entry.value as Map);
      data['id'] = entry.key;
      list.add(data);
    }

    // limitToLast já retorna em ordem crescente, mas garantimos aqui
    list.sort((a, b) =>
        (a['created_at'] as int? ?? 0).compareTo(b['created_at'] as int? ?? 0));
    return list;
  }

  Future<void> addComentario({
    required String festaId,
    required String uid,
    required String userName,
    String? userAvatar,
    required String texto,
  }) async {
    final ref = _db.ref('Festas/$festaId/comentarios').push();
    // Escrita atômica: comentário + incremento do contador em uma única chamada
    await _db.ref().update({
      'Festas/$festaId/comentarios/${ref.key}': {
        'user_id': uid,
        'user_name': userName,
        if (userAvatar != null) 'user_avatar': userAvatar,
        'texto': texto,
        'created_at': ServerValue.timestamp,
      },
      // A CF onFestaComentarioCreated cuida do comment_count,
      // mas se não tiver CF ativa, isso garante o incremento:
      // 'Festas/$festaId/comment_count': ServerValue.increment(1),
      // ↑ descomente se não tiver Cloud Function para isso
    });
  }
  // ══════════════════════════════════════════════════════════════════════════
  //  CRUD BÁSICO
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteFesta(String festaId) async {
    // 1. Busca a festa para obter o banner
    final snap = await _festaRef(festaId).get();

    String? bannerUrl;
    if (snap.exists && snap.value != null) {
      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      bannerUrl = map['banner_url'] as String?;
    }

    // 2. Remove do Firebase
    await _festaRef(festaId).remove();

    // 3. Deleta banner do Storage/Cloudinary
    await CloudinaryCleanupHelper.instance.deleteAsset(bannerUrl, 'image');
  }

  Future<void> updateFesta(
    String festaId,
    Map<String, dynamic> updates,
  ) async {
    final toWrite = <String, dynamic>{};
    final toRemove = <String>[];

    for (final entry in updates.entries) {
      if (entry.value == null) {
        toRemove.add(entry.key);
      } else {
        toWrite[entry.key] = entry.value;
      }
    }

    final ref = _festaRef(festaId);
    if (toWrite.isNotEmpty) await ref.update(toWrite);
    for (final key in toRemove) {
      await ref.child(key).remove();
    }
  }
}
