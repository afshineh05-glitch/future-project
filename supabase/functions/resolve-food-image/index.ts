import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  displayNameForFood,
  normalizeFoodKey,
} from "./food-key.ts";

const BUCKET = "food-visuals";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type FoodVisualRow = {
  food_key: string;
  display_name: string;
  image_url: string;
  storage_path: string;
  source: string;
};

type PexelsPhoto = {
  id?: number | string;
  url?: string;
  alt?: string;
  src?: {
    large?: string;
    large2x?: string;
    original?: string;
  };
};

type FoodSearchPlan = {
  query: string;
  requiredKeywords: string[];
};

const CANONICAL_SEARCH_QUERIES: Record<string, string> = {
  chicken_breast: "raw chicken breast isolated food",
  turkey: "raw turkey breast isolated food",
  eggs: "whole eggs isolated food",
  greek_yogurt: "plain greek yogurt bowl isolated food",
  lentils: "dry lentils bowl isolated food",
  tofu: "tofu cubes isolated food",
  rice: "cooked white rice bowl isolated food",
  potato: "whole potato isolated food",
  oats: "rolled oats bowl isolated food",
  beans: "beans bowl isolated food",
  whole_grain_bread: "whole grain bread isolated food",
  olive_oil: "olive oil bottle isolated food",
  avocado: "whole avocado isolated food",
  nuts: "mixed nuts isolated food",
  seeds: "mixed seeds isolated food",
};

const CANONICAL_REQUIRED_KEYWORDS: Record<string, string[]> = {
  chicken_breast: ["chicken"],
  turkey: ["turkey"],
  eggs: ["egg"],
  greek_yogurt: ["yogurt"],
  lentils: ["lentil"],
  tofu: ["tofu"],
  rice: ["rice"],
  potato: ["potato"],
  oats: ["oat"],
  beans: ["bean"],
  whole_grain_bread: ["bread"],
  olive_oil: ["olive", "oil"],
  avocado: ["avocado"],
  nuts: ["nut"],
  seeds: ["seed"],
};

const GENERIC_FOOD_WORDS = new Set([
  "and",
  "food",
  "fresh",
  "ingredient",
  "plain",
  "raw",
  "the",
  "whole",
]);

const BLOCKED_PHOTO_TERMS = [
  "advertisement",
  "brand",
  "chef",
  "delivery",
  "logo",
  "man",
  "menu",
  "package",
  "packaging",
  "person",
  "people",
  "plated meal",
  "restaurant",
  "takeaway",
  "text overlay",
  "woman",
];

const KNOWN_FOOD_KEYWORDS = [
  "almond",
  "avocado",
  "bean",
  "blueberry",
  "bread",
  "cheese",
  "chicken",
  "egg",
  "lentil",
  "nut",
  "oat",
  "olive",
  "potato",
  "quinoa",
  "rice",
  "salmon",
  "seed",
  "tofu",
  "turkey",
  "yogurt",
];

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function cachedResponse(row: FoodVisualRow) {
  return jsonResponse({
    food_key: row.food_key,
    display_name: row.display_name,
    image_url: row.image_url,
    source: "cache",
    cached: true,
  });
}

function fallbackResponse(
  foodKey: string,
  displayName: string,
  code: string,
  message: string,
  status = 502,
) {
  return jsonResponse({
    food_key: foodKey,
    display_name: displayName,
    image_url: null,
    source: "fallback",
    cached: false,
    error: { code, message },
  }, status);
}

async function findCached(
  admin: ReturnType<typeof createClient>,
  foodKey: string,
): Promise<FoodVisualRow | null> {
  const { data, error } = await admin
    .from("food_visuals")
    .select("food_key, display_name, image_url, storage_path, source")
    .eq("food_key", foodKey)
    .maybeSingle();

  if (error) throw error;
  return data as FoodVisualRow | null;
}

async function waitForConcurrentCache(
  admin: ReturnType<typeof createClient>,
  foodKey: string,
): Promise<FoodVisualRow | null> {
  for (let attempt = 0; attempt < 8; attempt++) {
    const cached = await findCached(admin, foodKey);
    if (cached) return cached;
    await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1)));
  }
  return null;
}

function normalizeSearchText(value: string): string {
  return value
    .toLowerCase()
    .replaceAll(/[^a-z0-9]+/g, " ")
    .trim();
}

function containsKeyword(text: string, keyword: string): boolean {
  const normalizedKeyword = normalizeSearchText(keyword);
  return text.split(" ").some((word) =>
    word === normalizedKeyword ||
    word.startsWith(`${normalizedKeyword}s`) ||
    normalizedKeyword.startsWith(`${word}s`)
  );
}

function searchPlanFor(foodKey: string, displayName: string): FoodSearchPlan {
  const nameWords = normalizeSearchText(displayName)
    .split(" ")
    .filter((word) => word.length > 2 && !GENERIC_FOOD_WORDS.has(word));
  const requiredKeywords = CANONICAL_REQUIRED_KEYWORDS[foodKey] ?? nameWords;
  const query = CANONICAL_SEARCH_QUERIES[foodKey] ??
    `${displayName} isolated food ingredient`;
  return { query, requiredKeywords };
}

function photoRelevanceScore(
  photo: PexelsPhoto,
  requiredKeywords: string[],
): number | null {
  const metadata = normalizeSearchText(`${photo.alt ?? ""} ${photo.url ?? ""}`);
  if (!metadata) return null;
  if (BLOCKED_PHOTO_TERMS.some((term) =>
    term.includes(" ") ? metadata.includes(term) : containsKeyword(metadata, term)
  )) return null;

  // Every canonical keyword must be represented. This prevents, for example,
  // a chicken result from being stored for turkey, or an unrelated bottle from
  // being stored for olive oil.
  if (!requiredKeywords.every((keyword) => containsKeyword(metadata, keyword))) {
    return null;
  }

  const referencesDifferentFood = KNOWN_FOOD_KEYWORDS.some((keyword) =>
    containsKeyword(metadata, keyword) &&
    !requiredKeywords.some((required) =>
      containsKeyword(normalizeSearchText(required), keyword) ||
      containsKeyword(normalizeSearchText(keyword), required)
    )
  );
  if (referencesDifferentFood) return null;

  let score = requiredKeywords.reduce(
    (total, keyword) => total + (containsKeyword(metadata, keyword) ? 10 : 0),
    0,
  );
  for (const preferred of ["isolated", "ingredient", "raw", "fresh", "whole", "bowl"]) {
    if (metadata.includes(preferred)) score += 1;
  }
  return score;
}

function logFoodVisualResolution(details: {
  foodKey: string;
  searchQuery: string;
  imageId: string;
  description: string;
  validationResult: string;
}) {
  console.log([
    "FOOD VISUAL",
    `food_key: ${details.foodKey}`,
    `search_query: ${details.searchQuery}`,
    `selected Pexels image id: ${details.imageId}`,
    `selected alt/description: ${details.description}`,
    `validation result: ${details.validationResult}`,
    "cached: false",
  ].join("\n"));
}

async function searchPexels(
  apiKey: string,
  foodKey: string,
  displayName: string,
): Promise<{
  imageUrl: string;
  imageId: string;
  pageUrl: string | null;
  query: string;
} | null> {
  const { query, requiredKeywords } = searchPlanFor(foodKey, displayName);
  const url = new URL("https://api.pexels.com/v1/search");
  url.searchParams.set("query", query);
  url.searchParams.set("per_page", "12");
  url.searchParams.set("orientation", "square");

  const response = await fetch(url, {
    headers: { Authorization: apiKey },
    signal: AbortSignal.timeout(12000),
  });
  if (!response.ok) {
    throw new Error(`Pexels search returned ${response.status}.`);
  }

  const payload = await response.json() as { photos?: PexelsPhoto[] };
  const selected = (payload.photos ?? [])
    .map((item) => ({
      item,
      score: photoRelevanceScore(item, requiredKeywords),
    }))
    .filter((candidate) => {
      const source = candidate.item.src?.large2x ??
        candidate.item.src?.large ?? candidate.item.src?.original;
      return Boolean(source) && candidate.score !== null;
    })
    .sort((left, right) => (right.score ?? 0) - (left.score ?? 0))[0];
  if (!selected) {
    logFoodVisualResolution({
      foodKey,
      searchQuery: query,
      imageId: "none",
      description: "none",
      validationResult: "failed - no relevant candidate",
    });
    return null;
  }

  const photo = selected.item;

  const imageUrl = photo.src?.large2x ?? photo.src?.large ?? photo.src?.original;
  if (!imageUrl) return null;

  logFoodVisualResolution({
    foodKey,
    searchQuery: query,
    imageId: String(photo.id ?? "unknown"),
    description: String(photo.alt ?? "none"),
    validationResult: `passed - relevance score ${selected.score}`,
  });

  return {
    imageUrl,
    imageId: String(photo.id ?? ""),
    pageUrl: photo.url?.trim() || null,
    query,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
  const serviceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
  const pexelsApiKey = Deno.env.get("PEXELS_API_KEY")?.trim() ?? "";
  const authorization = req.headers.get("Authorization") ?? "";

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "Server configuration is incomplete." }, 500);
  }
  if (!authorization.startsWith("Bearer ")) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  const { data: userData, error: userError } =
    await userClient.auth.getUser();
  if (userError || !userData.user?.id) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  let foodKey = "";
  let displayName = "";
  let uploadedByThisRequest = false;
  let storagePath = "";

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  try {
    const body = await req.json() as Record<string, unknown>;
    const foodName = String(body.food_name ?? "").trim();
    foodKey = normalizeFoodKey(foodName);
    displayName = displayNameForFood(foodName);

    if (!foodName || !foodKey) {
      return fallbackResponse(
        foodKey,
        displayName,
        "invalid_food_name",
        "food_name is required.",
        400,
      );
    }

    const cached = await findCached(admin, foodKey);
    if (cached) return cachedResponse(cached);

    if (!pexelsApiKey) {
      return fallbackResponse(
        foodKey,
        displayName,
        "image_provider_unavailable",
        "Ingredient imagery is temporarily unavailable.",
        503,
      );
    }

    const selected = await searchPexels(pexelsApiKey, foodKey, displayName);
    if (!selected) {
      return fallbackResponse(
        foodKey,
        displayName,
        "no_suitable_image",
        "No suitable ingredient image was found.",
        404,
      );
    }

    const imageResponse = await fetch(selected.imageUrl, {
      signal: AbortSignal.timeout(20000),
    });
    if (!imageResponse.ok) {
      throw new Error(`Ingredient image download returned ${imageResponse.status}.`);
    }
    const contentType = imageResponse.headers.get("content-type") ?? "";
    if (!contentType.toLowerCase().startsWith("image/jpeg")) {
      throw new Error("Image provider did not return a JPEG image.");
    }

    const imageBytes = new Uint8Array(await imageResponse.arrayBuffer());
    if (imageBytes.byteLength === 0 || imageBytes.byteLength > 10485760) {
      throw new Error("Ingredient image size is invalid.");
    }

    storagePath = `foods/${foodKey}.jpg`;
    const { error: uploadError } = await admin.storage
      .from(BUCKET)
      .upload(storagePath, imageBytes, {
        contentType: "image/jpeg",
        cacheControl: "31536000",
        upsert: false,
      });

    if (uploadError) {
      const concurrent = await waitForConcurrentCache(admin, foodKey);
      if (concurrent) return cachedResponse(concurrent);
      throw new Error(`Could not cache ingredient image: ${uploadError.message}`);
    }
    uploadedByThisRequest = true;

    const { data: publicUrlData } = admin.storage
      .from(BUCKET)
      .getPublicUrl(storagePath);
    const imageUrl = publicUrlData.publicUrl;

    const row = {
      food_key: foodKey,
      display_name: displayName,
      image_url: imageUrl,
      storage_path: storagePath,
      source: "pexels",
      source_image_id: selected.imageId || null,
      source_page_url: selected.pageUrl,
      search_query: selected.query,
    };
    const { data: inserted, error: insertError } = await admin
      .from("food_visuals")
      .upsert(row, { onConflict: "food_key", ignoreDuplicates: true })
      .select("food_key, display_name, image_url, storage_path, source")
      .maybeSingle();

    if (insertError) throw insertError;
    if (!inserted) {
      const concurrent = await waitForConcurrentCache(admin, foodKey);
      if (concurrent) return cachedResponse(concurrent);
      throw new Error("Could not finalize the ingredient image cache.");
    }

    return jsonResponse({
      food_key: inserted.food_key,
      display_name: inserted.display_name,
      image_url: inserted.image_url,
      source: "pexels",
      cached: false,
    });
  } catch (error) {
    console.error("resolve-food-image error:", error);
    if (uploadedByThisRequest && storagePath) {
      await admin.storage.from(BUCKET).remove([storagePath]);
    }
    return fallbackResponse(
      foodKey,
      displayName,
      "food_visual_unavailable",
      "Ingredient imagery is temporarily unavailable.",
    );
  }
});
