// src/sync_vip_of.ts
//
// NÍVEL 2.4 — CF que mantém o nó invertido vip_of/{uid}.
// Quando alguém me adiciona como VIP friend, a CF grava em MEU nó vip_of.
// Assim o feed lê 1 vez Users/$myUid/vip_of em vez de N reads individuais.
//
// Trigger: Users/{uid}/vip_friends/{friendUid}
//   - Se criado/true:  set Users/{friendUid}/vip_of/{uid} = true
//   - Se deletado:     remove Users/{friendUid}/vip_of/{uid}

import { onValueWritten } from "firebase-functions/v2/database";
import { getDatabase }    from "firebase-admin/database";

export const syncVipOf = onValueWritten(
  { ref: "Users/{uid}/vip_friends/{friendUid}", region: "us-central1", instance: "tropical-64d1b-default-rtdb", timeoutSeconds: 100 },
  async (event) => {
    const { uid, friendUid } = event.params;
    const db = getDatabase();

    const after = event.data.after.val();

    if (after === true || after !== null) {
      // VIP amigo adicionado — marcar no nó invertido do friendUid
      await db.ref(`Users/${friendUid}/vip_of/${uid}`).set(true);
      console.log(`[syncVipOf] ${uid} adicionou ${friendUid} como VIP → set vip_of`);
    } else {
      // VIP amigo removido — limpar do nó invertido
      await db.ref(`Users/${friendUid}/vip_of/${uid}`).remove();
      console.log(`[syncVipOf] ${uid} removeu ${friendUid} do VIP → remove vip_of`);
    }

    return null;
  }
);