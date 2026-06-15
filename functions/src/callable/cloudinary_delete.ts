// functions/src/cloudinary_delete.ts

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");
const cloudinaryApiKey    = defineSecret("CLOUDINARY_API_KEY");
const cloudinaryCloudName = defineSecret("CLOUDINARY_CLOUD_NAME");

export const deleteCloudinaryAsset = onCall(
  {
    region:  "us-central1",
    secrets: [cloudinaryApiSecret, cloudinaryApiKey, cloudinaryCloudName],
  timeoutSeconds: 100,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login necessário");
    }

    const { publicId, resourceType = "image" } = request.data as {
      publicId: string;
      resourceType?: string;
    };

    if (!publicId || typeof publicId !== "string") {
      throw new HttpsError("invalid-argument", "publicId inválido");
    }

    // Validação de ownership: o UID deve aparecer no caminho do asset.
    // Pastas válidas: users/{uid}/…, gallery/{uid}/…, posts/{uid}/…, stories/{uid}/…
    const ALLOWED_PREFIXES = ["users", "gallery", "posts", "stories"];
    const uid = request.auth.uid;
    const parts = publicId.split("/");

    // Formato esperado: {prefix}/{uid}/…  (mínimo 2 segmentos)
    const prefix  = parts[0];
    const pathUid = parts[1];

    if (
      parts.length < 2 ||
      !ALLOWED_PREFIXES.includes(prefix) ||
      pathUid !== uid
    ) {
      throw new HttpsError(
        "permission-denied",
        "Você não tem permissão para deletar este asset"
      );
    }

    // import dentro da função — igual ao padrão do cloudinary_signature.ts
    const crypto = await import("crypto");

    const timestamp = Math.round(Date.now() / 1000);
    const toSign    = `public_id=${publicId}&timestamp=${timestamp}${cloudinaryApiSecret.value()}`;
    const signature = crypto
      .createHash("sha1")
      .update(toSign)
      .digest("hex");

    const cloudName = cloudinaryCloudName.value();
    const url = `https://api.cloudinary.com/v1_1/${cloudName}/${resourceType}/destroy`;

    const body = new URLSearchParams({
      public_id: publicId,
      signature,
      api_key:   cloudinaryApiKey.value(),
      timestamp: String(timestamp),
    });

    const response = await fetch(url, {
      method:  "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:    body.toString(),
    });

    const result = (await response.json()) as { result?: string; error?: { message: string } };

    if (!response.ok || result.result === "error" || result.error) {
      const msg = result.error?.message ?? "Erro ao deletar no Cloudinary";
      console.error(`[deleteCloudinaryAsset] Cloudinary error: ${msg}`, result);
      throw new HttpsError("internal", msg);
    }

    console.log(
      `[deleteCloudinaryAsset] Deleted ${publicId} by uid=${request.auth.uid}. Result: ${result.result}`
    );

    return { success: true, result: result.result };
  }
);