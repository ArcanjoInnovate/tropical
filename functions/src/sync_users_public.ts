// functions/src/sync_users_public.ts
//
// Cloud Function: syncUsersPublic
//
// Mantém o nó UsersPublic/{uid} sincronizado com Users/{uid}.
//
// Motivação de segurança:
//   Users/{uid} agora tem .read restrito ao próprio dono — campos
//   sensíveis (email, fcmToken, latitude, longitude, presence,
//   blocked_users) não são mais expostos para terceiros.
//   UsersPublic/{uid} expõe apenas os campos que outros usuários
//   precisam ver para exibir perfis, feeds e buscas.
//
// Campos copiados para UsersPublic:
//   name, username, bio, avatar, bairro, city, state, gender,
//   followers_count, following_count, is_verified
//
// Campos NUNCA copiados (ficam apenas em Users):
//   email, fcmToken, latitude, longitude, presence,
//   blocked_users, vip_friends, vip_of, penalidades,
//   banido, suspenso, suspensao_fim, penalidade_ativa
//
// Trigger: onValueWritten em Users/{uid}
//   - Criação/atualização → sincroniza UsersPublic/{uid}
//   - Deleção → remove UsersPublic/{uid}

import { onValueWritten } from "firebase-functions/v2/database";
import { getDatabase }    from "firebase-admin/database";

const REGION   = "us-central1";
const INSTANCE = "tabuapp-4325a-default-rtdb";

// Campos permitidos em UsersPublic — whitelist explícita
const PUBLIC_FIELDS = [
  "name",
  "username",
  "bio",
  "avatar",
  "bairro",
  "city",
  "state",
  "gender",
  "followers_count",
  "following_count",
  "is_verified",
] as const;

export const syncUsersPublic = onValueWritten(
  { ref: "Users/{uid}", region: REGION, instance: INSTANCE },
  async (event) => {
    const uid = event.params.uid;
    const db  = getDatabase();
    const after = event.data.after.val() as Record<string, unknown> | null;

    // Usuário deletado — remove o nó público também
    if (!after) {
      await db.ref(`UsersPublic/${uid}`).remove();
      console.log(`[syncUsersPublic] Removido uid=${uid}`);
      return null;
    }

    // Sem nome = perfil incompleto, não expõe publicamente
    const name = (after.name ?? "").toString().trim();
    if (!name) {
      await db.ref(`UsersPublic/${uid}`).remove();
      console.log(`[syncUsersPublic] Sem nome, removido uid=${uid}`);
      return null;
    }

    // Monta o objeto público copiando apenas campos da whitelist
    const publicData: Record<string, unknown> = {};

    for (const field of PUBLIC_FIELDS) {
      const val = after[field];
      if (val !== undefined && val !== null) {
        publicData[field] = val;
      }
    }

    // Bio truncada em 150 chars para economizar banda
    if (typeof publicData.bio === "string" && publicData.bio.length > 150) {
      publicData.bio = publicData.bio.substring(0, 150);
    }

    // Garante que followers_count e following_count são números
    if (typeof publicData.followers_count !== "number") {
      publicData.followers_count = after.followers && typeof after.followers === "object"
        ? Object.keys(after.followers as object).length
        : 0;
    }
    if (typeof publicData.following_count !== "number") {
      publicData.following_count = after.following && typeof after.following === "object"
        ? Object.keys(after.following as object).length
        : 0;
    }

    await db.ref(`UsersPublic/${uid}`).set(publicData);
    console.log(`[syncUsersPublic] Sincronizado uid=${uid} campos=${Object.keys(publicData).join(", ")}`);
    return null;
  }
);