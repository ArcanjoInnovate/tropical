// src/cloudinary_signature.ts

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret }       from "firebase-functions/params";

const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");
const cloudinaryApiKey    = defineSecret("CLOUDINARY_API_KEY");

export const getUploadSignature = onCall(
  {
    region:  "us-central1",
    secrets: [cloudinaryApiSecret, cloudinaryApiKey],
    // TODO: reativar quando App Check for implementado no cliente
    // enforceAppCheck: true,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login necessário");
    }

    // Recebe folder e public_id do cliente (opcionais)
    const clientFolder   = request.data?.folder   as string | undefined;
    const clientPublicId = request.data?.public_id as string | undefined;

    // Garante que o folder sempre começa com o uid do usuário autenticado
    // para evitar que um usuário faça upload na pasta de outro
    const uid           = request.auth.uid;
    const defaultFolder = `users/${uid}`;
    const folder        = clientFolder?.startsWith(uid) ||
                          clientFolder?.startsWith(`stories/${uid}`)
                            ? clientFolder
                            : defaultFolder;

    const timestamp = Math.round(Date.now() / 1000);

    // Monta os parâmetros que serão assinados (ordenados alfabeticamente)
    const params: Record<string, string> = {
      folder,
      timestamp: String(timestamp),
    };
    if (clientPublicId) params.public_id = clientPublicId;

    const crypto = await import("crypto");

    // String to sign: chaves ordenadas alfabeticamente, sem api_key e sem file
    const toSign =
      Object.keys(params)
        .sort()
        .map((k) => `${k}=${params[k]}`)
        .join("&") + cloudinaryApiSecret.value();

    const signature = crypto
      .createHash("sha1")
      .update(toSign)
      .digest("hex");

    return {
      timestamp,
      signature,
      folder,
      publicId:  clientPublicId ?? null,
      apiKey:    cloudinaryApiKey.value(),
    };
  }
);