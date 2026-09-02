import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  buildPrompt,
  canonicalContext,
  HORIZON_MONTHS,
  persistenceMetadata,
  placeholderTemplateId,
  privateOutputPath,
  templateAssetReference,
  validationMessage,
  type FutureSelfMode,
  type PhotoAnalysis,
} from "./logic.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, "Content-Type": "application/json" },
});

const bytesToBase64 = (bytes: Uint8Array) => {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  }
  return btoa(binary);
};

const decodeBase64 = (value: string) => {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
};

const blobDataUrl = async (blob: Blob) => {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  return `data:${blob.type || "image/jpeg"};base64,${bytesToBase64(bytes)}`;
};

const extractResponseText = (result: any) => {
  if (typeof result?.output_text === "string") return result.output_text;
  for (const item of result?.output ?? []) {
    for (const content of item?.content ?? []) {
      if (typeof content?.text === "string") return content.text;
    }
  }
  return "";
};

const validatePhoto = async (
  openAiKey: string,
  photo: Blob,
  mode: FutureSelfMode,
): Promise<{ message: string | null; safetyRejected: boolean }> => {
  const imageUrl = await blobDataUrl(photo);
  const moderationResponse = await fetch("https://api.openai.com/v1/moderations", {
    method: "POST",
    headers: { Authorization: `Bearer ${openAiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "omni-moderation-latest",
      input: [{ type: "image_url", image_url: { url: imageUrl } }],
    }),
  });
  const moderation = await moderationResponse.json();
  if (!moderationResponse.ok) throw new Error("photo_moderation_failed");
  const moderationResult = moderation?.results?.[0];
  if (moderationResult?.flagged || moderationResult?.categories?.sexual === true) {
    return { message: "Use a photo in regular workout clothing.", safetyRejected: true };
  }

  const validationResponse = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: { Authorization: `Bearer ${openAiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "gpt-5-mini",
      input: [{
        role: "user",
        content: [
          {
            type: "input_text",
            text: `Assess this private fitness-reference photo conservatively. Return JSON only. Mode: ${mode}. Do not identify the person or infer health, ethnicity, attractiveness, or medical conditions.`,
          },
          { type: "input_image", image_url: imageUrl },
        ],
      }],
      text: {
        format: {
          type: "json_schema",
          name: "future_self_photo_validation",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              personCount: { anyOf: [{ type: "integer" }, { type: "null" }] },
              faceVisible: { anyOf: [{ type: "boolean" }, { type: "null" }] },
              fullBodyVisible: { anyOf: [{ type: "boolean" }, { type: "null" }] },
              excessivelyCropped: { anyOf: [{ type: "boolean" }, { type: "null" }] },
              usablePose: { anyOf: [{ type: "boolean" }, { type: "null" }] },
              adequateLighting: { anyOf: [{ type: "boolean" }, { type: "null" }] },
              ordinaryNonSexualClothing: { anyOf: [{ type: "boolean" }, { type: "null" }] },
              sexualizedPoseOrNudity: { anyOf: [{ type: "boolean" }, { type: "null" }] },
            },
            required: ["personCount", "faceVisible", "fullBodyVisible", "excessivelyCropped", "usablePose", "adequateLighting", "ordinaryNonSexualClothing", "sexualizedPoseOrNudity"],
          },
        },
      },
    }),
  });
  const validationResult = await validationResponse.json();
  if (!validationResponse.ok) throw new Error("photo_validation_failed");
  const text = extractResponseText(validationResult);
  const analysis = JSON.parse(text) as PhotoAnalysis;
  return { message: validationMessage(analysis, mode), safetyRejected: false };
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
    const openAiKey = Deno.env.get("OPENAI_API_KEY")?.trim() ?? "";
    const authorization = req.headers.get("Authorization") ?? "";
    if (!supabaseUrl || !anonKey || !serviceRoleKey || !openAiKey) {
      return json({ error: "Generation service is not configured." }, 503);
    }
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);
    const user = userData.user;
    const payload = await req.json().catch(() => ({}));
    const clientRequest = payload?.request ?? {};
    const { data: vision, error: visionError } = await userClient
      .from("vision_profiles")
      .select("primary_goal, desired_feelings, future_identity, current_photo_path, current_photo_input_mode, future_self_input_mode, future_self_image_path")
      .eq("user_id", user.id)
      .single();
    if (visionError || !vision?.current_photo_path) {
      return json({ error: "Add a current photo before generating." }, 400);
    }
    const { data: foundation, error: foundationError } = await userClient
      .from("user_foundations")
      .select("age, sex, height_cm, weight_kg, target_weight_kg, waist_cm, chest_cm, hips_cm, arm_cm, thigh_cm, neck_cm, training_level, primary_goal, body_type")
      .eq("user_id", user.id)
      .maybeSingle();
    if (foundationError) throw foundationError;
    let context;
    try {
      context = canonicalContext(clientRequest, vision, foundation ?? {});
    } catch (error) {
      return json({ error: String(error) }, 409);
    }
    if (Number(clientRequest.futureHorizonMonths) !== HORIZON_MONTHS) {
      return json({ error: "The Future Self horizon must be 8 months." }, 400);
    }
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: currentPhoto, error: downloadError } = await userClient.storage
      .from("future-self-images")
      .download(context.currentPhotoPath);
    if (downloadError || !currentPhoto) {
      return json({ error: "The current photo could not be loaded." }, 400);
    }
    const validation = await validatePhoto(openAiKey, currentPhoto, context.mode);
    if (validation.message) {
      return json({
        code: validation.safetyRejected
          ? "future_self_photo_rejected"
          : "future_self_validation_failed",
        error: validation.message,
      }, 422);
    }

    const sourceImages: Array<{ blob: Blob; name: string }> = [
      { blob: currentPhoto, name: `current-photo.${currentPhoto.type === "image/png" ? "png" : currentPhoto.type === "image/webp" ? "webp" : "jpg"}` },
    ];
    let sourceReference = context.currentPhotoPath;
    if (context.mode === "face_only") {
      const templateId = placeholderTemplateId(foundation ?? {});
      if (clientRequest.bodyTemplateId !== templateId) {
        return json({ error: "The body template reference is out of date." }, 409);
      }
      const templatePath = templateAssetReference(templateId);
      if (templatePath) {
        const { data: template, error: templateError } = await admin.storage
          .from("future-self-images")
          .download(templatePath);
        if (templateError || !template) {
          console.warn("Future Self body template could not be loaded; using profile fallback", {
            templateId,
            templatePath,
          });
        } else {
          sourceImages.push({ blob: template, name: "neutral-body-template.png" });
        }
      }
      sourceReference = templatePath ? templateId : `profile:${templateId}`;
    }

    const form = new FormData();
    form.append("model", "gpt-image-2");
    for (const image of sourceImages) form.append("image[]", image.blob, image.name);
    form.append("prompt", buildPrompt(context));
    form.append("size", "1024x1536");
    form.append("quality", "medium");
    form.append("output_format", "png");
    form.append("moderation", "auto");
    form.append("user", user.id);
    const openAiResponse = await fetch("https://api.openai.com/v1/images/edits", {
      method: "POST",
      headers: { Authorization: `Bearer ${openAiKey}` },
      body: form,
    });
    const requestId = openAiResponse.headers.get("x-request-id");
    const result = await openAiResponse.json();
    if (!openAiResponse.ok || !result?.data?.[0]?.b64_json) {
      const providerError = result?.error;
      const errorCode = String(providerError?.code ?? "");
      const errorMessage = String(providerError?.message ?? "");
      console.error("OpenAI Future Self generation failed", {
        status: openAiResponse.status,
        requestId,
        errorCode,
        error: errorMessage || "No image returned",
      });
      if (errorCode === "moderation_blocked" || /safety|moderation/i.test(errorMessage)) {
        return json({
          code: "future_self_photo_rejected",
          error: "This photo can't be used. Please choose another photo in regular workout clothing.",
        }, 422);
      }
      return json({ error: "Couldn't create your Future Self." }, 502);
    }
    const generatedAt = new Date();
    const outputPath = privateOutputPath(user.id, generatedAt.getTime());
    const { error: uploadError } = await admin.storage
      .from("future-self-images")
      .upload(outputPath, decodeBase64(result.data[0].b64_json), {
        contentType: "image/png",
        cacheControl: "3600",
        upsert: false,
      });
    if (uploadError) throw uploadError;
    const previousPath = vision.future_self_image_path as string | null;
    const { error: updateError } = await admin
      .from("vision_profiles")
      .update({
        future_self_image_path: outputPath,
        future_self_generated_at: generatedAt.toISOString(),
        ...persistenceMetadata(context.mode, sourceReference, context.primaryGoal),
        updated_at: generatedAt.toISOString(),
      })
      .eq("user_id", user.id);
    if (updateError) {
      await admin.storage.from("future-self-images").remove([outputPath]);
      throw updateError;
    }
    if (previousPath && previousPath !== outputPath) {
      await admin.storage.from("future-self-images").remove([previousPath]);
    }
    return json({
      futureSelfImagePath: outputPath,
      generatedAt: generatedAt.toISOString(),
      inputMode: context.mode,
      futureHorizonMonths: HORIZON_MONTHS,
    });
  } catch (error) {
    console.error("Unexpected Future Self generation failure", error);
    return json({ error: "Couldn't create your Future Self." }, 500);
  }
});
