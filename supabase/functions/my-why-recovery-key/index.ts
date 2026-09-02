import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json" },
});

const encode = (bytes: Uint8Array) => {
  let binary = "";
  for (let index = 0; index < bytes.length; index += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 0x8000));
  }
  return btoa(binary);
};
const decode = (value: string) => {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
};
const aad = (userId: string) => new TextEncoder().encode(`my-why:recovery:v1:${userId}`);

const recoveryKek = async () => {
  const encoded = Deno.env.get("MY_WHY_RECOVERY_KEK_BASE64")?.trim() ?? "";
  const key = encoded ? decode(encoded) : new Uint8Array();
  if (key.length !== 32) throw new Error("recovery_key_not_configured");
  return crypto.subtle.importKey("raw", key, { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
};

const wrap = async (key: Uint8Array, userId: string) => {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = new Uint8Array(await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, additionalData: aad(userId), tagLength: 128 },
    await recoveryKek(),
    key,
  ));
  return {
    wrapped_key_ciphertext: encode(encrypted.slice(0, -16)),
    wrapped_key_nonce: encode(nonce),
    wrapped_key_mac: encode(encrypted.slice(-16)),
    wrapping_version: 1,
  };
};

const unwrap = async (row: Record<string, unknown>, userId: string) => {
  const cipherText = decode(String(row.wrapped_key_ciphertext));
  const mac = decode(String(row.wrapped_key_mac));
  const encrypted = new Uint8Array(cipherText.length + mac.length);
  encrypted.set(cipherText);
  encrypted.set(mac, cipherText.length);
  const key = new Uint8Array(await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: decode(String(row.wrapped_key_nonce)), additionalData: aad(userId), tagLength: 128 },
    await recoveryKek(),
    encrypted,
  ));
  if (key.length !== 32) throw new Error("invalid_recovered_key");
  return key;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
    const authorization = req.headers.get("Authorization") ?? "";
    if (!url || !anonKey || !serviceRoleKey) return json({ error: "Recovery service is not configured." }, 503);
    const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);
    const userId = userData.user.id;
    const admin = createClient(url, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const request = await req.json().catch(() => ({}));
    const operation = request?.operation;
    const { data: existing, error: readError } = await admin
      .from("my_why_key_envelopes")
      .select("wrapped_key_ciphertext, wrapped_key_nonce, wrapped_key_mac, wrapping_version")
      .eq("user_id", userId)
      .maybeSingle();
    if (readError) throw readError;
    if (operation === "delete_envelope") {
      const { error } = await admin.from("my_why_key_envelopes").delete().eq("user_id", userId);
      if (error) throw error;
      return json({ deleted: true });
    }
    if (existing) return json({ key_base64: encode(await unwrap(existing, userId)) });
    let key: Uint8Array;
    if (operation === "register_legacy_key") {
      key = decode(String(request?.legacy_key_base64 ?? ""));
      if (key.length !== 32) return json({ error: "Invalid legacy key." }, 400);
    } else if (operation === "recover_or_create") {
      key = crypto.getRandomValues(new Uint8Array(32));
    } else {
      return json({ error: "Unsupported recovery operation." }, 400);
    }
    const { error: insertError } = await admin
      .from("my_why_key_envelopes")
      .insert({ user_id: userId, ...(await wrap(key, userId)) });
    if (insertError) {
      if (insertError.code !== "23505") throw insertError;
      const { data: raced, error: racedError } = await admin
        .from("my_why_key_envelopes")
        .select("wrapped_key_ciphertext, wrapped_key_nonce, wrapped_key_mac, wrapping_version")
        .eq("user_id", userId)
        .single();
      if (racedError) throw racedError;
      key = await unwrap(raced, userId);
    }
    return json({ key_base64: encode(key) });
  } catch (error) {
    console.error("my_why_recovery_key_failed", error instanceof Error ? error.message : "unknown");
    return json({ error: "My Why key recovery failed." }, 500);
  }
});
