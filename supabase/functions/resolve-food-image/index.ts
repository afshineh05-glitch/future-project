import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

import {
  displayNameForFood,
  normalizeFoodKey,
} from "./food-key.ts";

const BUCKET = "ingredient-images";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-image-refresh-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type FoodVisualRow = {
  food_key: string;
  display_name: string;
  image_url: string | null;
  storage_path: string | null;
  source: string;
  status: "ready" | "missing" | "failed";
  retry_after: string | null;
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

type PixabayPhoto = {
  id?: number | string;
  pageURL?: string;
  largeImageURL?: string;
  webformatURL?: string;
  tags?: string;
  user?: string;
};

type IngredientCategory =
  | "raw_protein"
  | "seafood"
  | "dairy"
  | "fruit"
  | "vegetable"
  | "nuts_seeds"
  | "grain_legume"
  | "pantry";

type FoodSearchPlan = {
  foodKey: string;
  query: string;
  requiredKeywords: string[];
  preferredKeywords: string[];
  category: IngredientCategory;
};

type ProviderSelection = {
  imageUrl: string;
  imageId: string;
  pageUrl: string | null;
  query: string;
  provider: "pexels" | "pixabay";
};

type CuratorCandidate = {
  provider: "pexels" | "pixabay";
  providerId: string;
  previewUrl: string;
  downloadUrl: string;
  metadata: string;
  score: number;
  pageUrl: string | null;
  query: string;
};

type CandidateTokenPayload = CuratorCandidate & {
  ingredientKey: string;
  expiresAt: number;
};

type PixabayDiagnostic = {
  status:
    | "ok"
    | "missing_key"
    | "http_error"
    | "api_error"
    | "zero_hits"
    | "filtered_out";
  httpStatus: number | null;
  rawHitCount: number;
  acceptedCount: number;
};

type PixabayCandidateResult = {
  candidates: CuratorCandidate[];
  diagnostic: PixabayDiagnostic;
};

const CANONICAL_SEARCH_QUERIES: Record<string, string> = {
  chicken_breast: "raw chicken breast isolated food",
  chicken_thigh: "raw chicken thigh isolated food",
  turkey: "raw turkey breast meat",
  lean_ground_turkey: "raw ground turkey meat",
  lean_beef: "raw lean beef meat",
  ground_beef: "raw ground beef",
  steak: "raw beef steak",
  pork_tenderloin: "raw pork tenderloin meat",
  fish: "raw fish fillet isolated seafood",
  salmon: "raw salmon fillet",
  tuna: "raw tuna steak",
  cod: "raw cod fillet",
  tilapia: "raw tilapia fillet",
  trout: "raw trout fillet",
  shrimp: "raw shrimp seafood",
  sardines: "plain sardines fish",
  eggs: "whole chicken eggs",
  egg_whites: "egg whites food",
  tofu: "plain tofu blocks",
  tempeh: "plain tempeh blocks",
  greek_yogurt: "plain greek yogurt",
  cottage_cheese: "plain cottage cheese",
  milk: "milk glass bottle",
  skim_milk: "skim milk glass bottle",
  broccoli: "fresh broccoli vegetable",
  banana: "whole fresh bananas",
  apple: "whole fresh apple",
  orange: "fresh whole orange fruit isolated",
  grapes: "fresh grape bunch",
  blueberries: "fresh blueberries fruit",
  strawberries: "fresh strawberries fruit",
  almonds: "plain raw almonds",
  walnuts: "raw walnuts food",
  cashews: "raw cashew nuts food",
  lentils: "dry lentils bowl isolated food",
  rice: "cooked white rice bowl isolated food",
  potato: "whole potato isolated food",
  oats: "rolled oats bowl isolated food",
  beans: "beans bowl isolated food",
  whole_grain_bread: "whole grain bread isolated food",
  olive_oil: "olive oil bottle food",
  avocado: "fresh avocado food",
  nuts: "mixed nuts isolated food",
  seeds: "mixed seeds isolated food",
};

const CANONICAL_REQUIRED_KEYWORDS: Record<string, string[]> = {
  chicken_breast: ["chicken"],
  chicken_thigh: ["chicken"],
  lean_ground_turkey: ["turkey"],
  lean_beef: ["beef"],
  ground_beef: ["beef"],
  steak: ["steak"],
  pork_tenderloin: ["pork"],
  fish: ["fish"],
  salmon: ["salmon"],
  tuna: ["tuna"],
  cod: ["cod"],
  tilapia: ["tilapia"],
  trout: ["trout"],
  shrimp: ["shrimp"],
  sardines: ["sardine"],
  broccoli: ["broccoli"],
  banana: ["banana"],
  apple: ["apple"],
  orange: ["orange"],
  grapes: ["grape"],
  blueberries: ["blueberry"],
  strawberries: ["strawberry"],
  almonds: ["almond"],
  walnuts: ["walnut"],
  cashews: ["cashew"],
  turkey: ["turkey"],
  eggs: ["egg"],
  egg_whites: ["egg"],
  greek_yogurt: ["yogurt"],
  cottage_cheese: ["cottage", "cheese"],
  milk: ["milk"],
  skim_milk: ["milk"],
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
  "art",
  "brand",
  "cake",
  "chef",
  "cocktail",
  "complete meal",
  "delivery",
  "dessert",
  "dinner",
  "dish",
  "drawing",
  "graphic",
  "juice",
  "lunch",
  "logo",
  "man",
  "menu",
  "package",
  "packaging",
  "person",
  "people",
  "plated meal",
  "poster",
  "pie",
  "restaurant",
  "salad",
  "smoothie",
  "tart",
  "takeaway",
  "text overlay",
  "table",
  "woman",
];

const COOKED_PROTEIN_TERMS = [
  "baked",
  "barbecue",
  "cooked",
  "fried",
  "grilled",
  "roasted",
  "seared",
  "smoked",
];

const RAW_PROTEIN_KEYS = new Set([
  "chicken_breast",
  "chicken_thigh",
  "turkey",
  "lean_ground_turkey",
  "lean_beef",
  "ground_beef",
  "steak",
  "pork_tenderloin",
]);
const SEAFOOD_KEYS = new Set([
  "fish",
  "salmon",
  "tuna",
  "cod",
  "tilapia",
  "trout",
  "shrimp",
  "sardines",
]);
const DAIRY_KEYS = new Set([
  "greek_yogurt",
  "cottage_cheese",
  "milk",
  "skim_milk",
  "cheese",
  "mozzarella",
  "feta",
]);
const FRUIT_KEYS = new Set([
  "banana",
  "apple",
  "orange",
  "berries",
  "blueberries",
  "strawberries",
  "grapes",
  "mango",
  "pineapple",
  "avocado",
  "lemon",
]);
const VEGETABLE_KEYS = new Set([
  "broccoli",
  "spinach",
  "lettuce",
  "tomato",
  "cucumber",
  "bell_pepper",
  "onion",
  "carrot",
  "mushroom",
  "zucchini",
  "asparagus",
  "green_beans",
  "cauliflower",
  "cabbage",
  "garlic",
]);
const NUT_SEED_KEYS = new Set([
  "almonds",
  "walnuts",
  "cashews",
  "chia_seeds",
  "flax_seeds",
  "peanut_butter",
  "almond_butter",
]);
const GRAIN_LEGUME_KEYS = new Set([
  "white_rice",
  "brown_rice",
  "basmati_rice",
  "oats",
  "potatoes",
  "sweet_potatoes",
  "pasta",
  "whole_wheat_pasta",
  "quinoa",
  "bread",
  "whole_wheat_bread",
  "tortilla",
  "couscous",
  "lentils",
  "chickpeas",
  "black_beans",
  "kidney_beans",
  "edamame",
]);

const KNOWN_FOOD_KEYWORDS = [
  "almond",
  "apple",
  "avocado",
  "banana",
  "bean",
  "blueberry",
  "bread",
  "cod",
  "cheese",
  "chicken",
  "egg",
  "fish",
  "lentil",
  "nut",
  "oat",
  "olive",
  "orange",
  "potato",
  "quinoa",
  "rice",
  "salmon",
  "shrimp",
  "seed",
  "tofu",
  "trout",
  "tuna",
  "turkey",
  "grape",
  "strawberry",
  "walnut",
  "cashew",
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
  if (row.status !== "ready" || !row.image_url) {
    return fallbackResponse(
      row.food_key,
      row.display_name,
      row.status === "missing" ? "no_suitable_image" : "food_visual_unavailable",
      "Ingredient imagery is temporarily unavailable.",
      200,
      true,
    );
  }
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
  cached = false,
) {
  return jsonResponse({
    food_key: foodKey,
    display_name: displayName,
    image_url: null,
    source: "fallback",
    cached,
    error: { code, message },
  }, status);
}

async function findCached(
  admin: ReturnType<typeof createClient>,
  foodKey: string,
): Promise<FoodVisualRow | null> {
  const { data, error } = await admin
    .from("food_visuals")
    .select("food_key, display_name, image_url, storage_path, source, status, retry_after")
    .eq("food_key", foodKey)
    .maybeSingle();

  if (error) throw error;
  return data as FoodVisualRow | null;
}

async function rememberFailure(
  admin: ReturnType<typeof createClient>,
  foodKey: string,
  displayName: string,
  status: "missing" | "failed",
) {
  if (!foodKey) return;
  const retryDays = status === "missing" ? 30 : 1;
  const retryAfter = new Date(Date.now() + retryDays * 86400000).toISOString();
  await admin.from("food_visuals").upsert({
    food_key: foodKey,
    display_name: displayName,
    image_url: null,
    storage_path: null,
    source: "providers",
    status,
    fetched_at: new Date().toISOString(),
    retry_after: retryAfter,
  }, { onConflict: "food_key" });
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
  const singular = (word: string) => {
    if (word.endsWith("ies") && word.length > 3) return `${word.slice(0, -3)}y`;
    if (word.endsWith("oes") && word.length > 3) return word.slice(0, -2);
    if (word.endsWith("s") && word.length > 3) return word.slice(0, -1);
    return word;
  };
  return text.split(" ").some((word) =>
    word === normalizedKeyword || singular(word) === singular(normalizedKeyword)
  );
}

function ingredientCategoryFor(foodKey: string): IngredientCategory {
  if (RAW_PROTEIN_KEYS.has(foodKey)) return "raw_protein";
  if (SEAFOOD_KEYS.has(foodKey)) return "seafood";
  if (DAIRY_KEYS.has(foodKey)) return "dairy";
  if (FRUIT_KEYS.has(foodKey)) return "fruit";
  if (VEGETABLE_KEYS.has(foodKey)) return "vegetable";
  if (NUT_SEED_KEYS.has(foodKey)) return "nuts_seeds";
  if (GRAIN_LEGUME_KEYS.has(foodKey)) return "grain_legume";
  return "pantry";
}

function fallbackQueryFor(
  displayName: string,
  category: IngredientCategory,
): string {
  const categoryPhrase: Record<IngredientCategory, string> = {
    raw_protein: "raw meat isolated ingredient",
    seafood: "raw seafood fillet isolated ingredient",
    dairy: "plain dairy product isolated",
    fruit: "whole fresh fruit isolated",
    vegetable: "whole fresh vegetable isolated",
    nuts_seeds: "plain raw nuts seeds isolated",
    grain_legume: "plain grain legume ingredient",
    pantry: "plain pantry ingredient product",
  };
  return `${displayName} ${categoryPhrase[category]}`;
}

function searchPlanFor(foodKey: string, displayName: string): FoodSearchPlan {
  const category = ingredientCategoryFor(foodKey);
  const nameWords = normalizeSearchText(displayName)
    .split(" ")
    .filter((word) => word.length > 2 && !GENERIC_FOOD_WORDS.has(word));
  const requiredKeywords = CANONICAL_REQUIRED_KEYWORDS[foodKey] ?? nameWords;
  const query = CANONICAL_SEARCH_QUERIES[foodKey] ??
    fallbackQueryFor(displayName, category);
  const preferredKeywords = normalizeSearchText(query)
    .split(" ")
    .filter((word) => word.length > 2 && !GENERIC_FOOD_WORDS.has(word));
  return { foodKey, query, requiredKeywords, preferredKeywords, category };
}

function photoRelevanceScore(
  metadataValue: string,
  plan: FoodSearchPlan,
): number | null {
  const metadata = normalizeSearchText(metadataValue);
  if (!metadata) return null;
  if (BLOCKED_PHOTO_TERMS.some((term) =>
    term.includes(" ") ? metadata.includes(term) : containsKeyword(metadata, term)
  )) return null;

  // Every canonical keyword must be represented. This prevents, for example,
  // a chicken result from being stored for turkey, or an unrelated bottle from
  // being stored for olive oil.
  if (!plan.requiredKeywords.every((keyword) => containsKeyword(metadata, keyword))) {
    return null;
  }

  if ((plan.category === "raw_protein" || plan.category === "seafood") &&
    COOKED_PROTEIN_TERMS.some((term) => containsKeyword(metadata, term))) {
    return null;
  }

  const categoryCompatibleKeywords = plan.foodKey === "fish"
    ? new Set(["fish", "salmon", "tuna", "cod", "trout"])
    : plan.foodKey === "eggs" || plan.foodKey === "egg_whites"
    ? new Set(["egg", "chicken"])
    : new Set<string>();
  const referencesDifferentFood = KNOWN_FOOD_KEYWORDS.some((keyword) =>
    containsKeyword(metadata, keyword) &&
    !categoryCompatibleKeywords.has(keyword) &&
    !plan.requiredKeywords.some((required) =>
      containsKeyword(normalizeSearchText(required), keyword) ||
      containsKeyword(normalizeSearchText(keyword), required)
    )
  );
  if (referencesDifferentFood) return null;

  let score = plan.requiredKeywords.reduce(
    (total, keyword) => total + (containsKeyword(metadata, keyword) ? 10 : 0),
    0,
  );
  score += plan.preferredKeywords.reduce(
    (total, keyword) => total + (containsKeyword(metadata, keyword) ? 2 : 0),
    0,
  );
  for (const preferred of [
    "isolated",
    "ingredient",
    "raw",
    "fresh",
    "whole",
    "fillet",
    "plain",
    "vegetable",
    "fruit",
    "meat",
    "seafood",
    "nuts",
  ]) {
    if (containsKeyword(metadata, preferred)) score += 2;
  }
  if ((plan.category === "raw_protein" || plan.category === "seafood") &&
    containsKeyword(metadata, "raw")) score += 6;
  if ((plan.category === "fruit" || plan.category === "vegetable") &&
    (containsKeyword(metadata, "fresh") || containsKeyword(metadata, "whole"))) {
    score += 4;
  }
  return score >= plan.requiredKeywords.length * 10 ? score : null;
}

function curatorRelevanceScore(
  metadataValue: string,
  plan: FoodSearchPlan,
): number | null {
  const metadata = normalizeSearchText(metadataValue);
  if (!metadata) return 0;
  if (BLOCKED_PHOTO_TERMS.some((term) =>
    term.includes(" ") ? metadata.includes(term) : containsKeyword(metadata, term)
  )) return null;

  let score = plan.requiredKeywords.reduce(
    (total, keyword) => total + (containsKeyword(metadata, keyword) ? 10 : 0),
    0,
  );
  score += plan.preferredKeywords.reduce(
    (total, keyword) => total + (containsKeyword(metadata, keyword) ? 2 : 0),
    0,
  );
  for (const preferred of [
    "isolated",
    "ingredient",
    "raw",
    "fresh",
    "whole",
    "fillet",
    "plain",
  ]) {
    if (containsKeyword(metadata, preferred)) score += 2;
  }
  if ((plan.category === "raw_protein" || plan.category === "seafood") &&
    COOKED_PROTEIN_TERMS.some((term) => containsKeyword(metadata, term))) {
    score -= 8;
  }
  return score;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function base64UrlDecode(value: string): Uint8Array {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/") +
    "=".repeat((4 - value.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function candidateSigningKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

async function signCandidate(
  candidate: CuratorCandidate,
  ingredientKey: string,
  secret: string,
): Promise<string> {
  const payload: CandidateTokenPayload = {
    ...candidate,
    ingredientKey,
    expiresAt: Date.now() + 10 * 60 * 1000,
  };
  const encodedPayload = base64UrlEncode(
    new TextEncoder().encode(JSON.stringify(payload)),
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    await candidateSigningKey(secret),
    new TextEncoder().encode(encodedPayload),
  );
  return `${encodedPayload}.${base64UrlEncode(new Uint8Array(signature))}`;
}

async function verifyCandidate(
  token: string,
  secret: string,
): Promise<CandidateTokenPayload | null> {
  const [encodedPayload, encodedSignature, ...extra] = token.split(".");
  if (!encodedPayload || !encodedSignature || extra.length > 0) return null;
  try {
    const valid = await crypto.subtle.verify(
      "HMAC",
      await candidateSigningKey(secret),
      base64UrlDecode(encodedSignature),
      new TextEncoder().encode(encodedPayload),
    );
    if (!valid) return null;
    const payload = JSON.parse(
      new TextDecoder().decode(base64UrlDecode(encodedPayload)),
    ) as CandidateTokenPayload;
    if (!Number.isFinite(payload.expiresAt) || payload.expiresAt < Date.now()) {
      return null;
    }
    return payload;
  } catch (_) {
    return null;
  }
}

function isAllowedProviderImageUrl(
  provider: "pexels" | "pixabay",
  value: string,
): boolean {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") return false;
    if (provider === "pexels") return url.hostname === "images.pexels.com";
    return url.hostname === "pixabay.com" ||
      url.hostname === "cdn.pixabay.com" ||
      url.hostname.endsWith(".pixabay.com");
  } catch (_) {
    return false;
  }
}

async function curatorPexelsCandidates(
  apiKey: string,
  foodKey: string,
  displayName: string,
  page: number,
): Promise<CuratorCandidate[]> {
  if (!apiKey) return [];
  const plan = searchPlanFor(foodKey, displayName);
  const url = new URL("https://api.pexels.com/v1/search");
  url.searchParams.set("query", plan.query);
  url.searchParams.set("per_page", "24");
  url.searchParams.set("page", String(page));
  url.searchParams.set("orientation", "square");
  const response = await fetch(url, {
    headers: { Authorization: apiKey },
    signal: AbortSignal.timeout(12000),
  });
  if (!response.ok) throw new Error(`Pexels search returned ${response.status}.`);
  const payload = await response.json() as { photos?: PexelsPhoto[] };
  return (payload.photos ?? []).map((photo) => {
    const downloadUrl = photo.src?.large2x ?? photo.src?.large ??
      photo.src?.original ?? "";
    const metadata = String(photo.alt ?? "").trim();
    return {
      provider: "pexels" as const,
      providerId: String(photo.id ?? ""),
      previewUrl: photo.src?.large ?? downloadUrl,
      downloadUrl,
      metadata,
      score: curatorRelevanceScore(`${metadata} ${photo.url ?? ""}`, plan),
      pageUrl: photo.url?.trim() || null,
      query: plan.query,
    };
  }).filter((candidate) =>
    candidate.providerId && candidate.previewUrl && candidate.downloadUrl &&
    candidate.score !== null &&
    isAllowedProviderImageUrl("pexels", candidate.downloadUrl)
  ).sort((left, right) => (right.score ?? 0) - (left.score ?? 0)).slice(0, 6)
    .map((candidate) => ({ ...candidate, score: candidate.score ?? 0 }));
}

async function curatorPixabayCandidates(
  apiKey: string,
  foodKey: string,
  displayName: string,
  page: number,
): Promise<PixabayCandidateResult> {
  if (!apiKey) {
    return {
      candidates: [],
      diagnostic: {
        status: "missing_key",
        httpStatus: null,
        rawHitCount: 0,
        acceptedCount: 0,
      },
    };
  }
  const plan = searchPlanFor(foodKey, displayName);
  const url = new URL("https://pixabay.com/api/");
  url.searchParams.set("key", apiKey);
  url.searchParams.set("q", plan.query);
  url.searchParams.set("image_type", "photo");
  url.searchParams.set("safesearch", "true");
  url.searchParams.set("per_page", "24");
  url.searchParams.set("page", String(page));
  let response: Response;
  try {
    response = await fetch(url, { signal: AbortSignal.timeout(12000) });
  } catch (_) {
    return {
      candidates: [],
      diagnostic: {
        status: "http_error",
        httpStatus: null,
        rawHitCount: 0,
        acceptedCount: 0,
      },
    };
  }
  const responseText = await response.text();
  let payload: { hits?: PixabayPhoto[]; error?: unknown } | null = null;
  try {
    payload = JSON.parse(responseText) as {
      hits?: PixabayPhoto[];
      error?: unknown;
    };
  } catch (_) {
    // Pixabay API errors may be returned as plain text.
  }
  if (!response.ok || payload?.error != null) {
    const isApiError = payload?.error != null ||
      responseText.trimStart().startsWith("[ERROR");
    return {
      candidates: [],
      diagnostic: {
        status: isApiError ? "api_error" : "http_error",
        httpStatus: response.status,
        rawHitCount: 0,
        acceptedCount: 0,
      },
    };
  }
  if (!payload) {
    return {
      candidates: [],
      diagnostic: {
        status: "api_error",
        httpStatus: response.status,
        rawHitCount: 0,
        acceptedCount: 0,
      },
    };
  }
  const hits = payload.hits ?? [];
  if (hits.length === 0) {
    return {
      candidates: [],
      diagnostic: {
        status: "zero_hits",
        httpStatus: response.status,
        rawHitCount: 0,
        acceptedCount: 0,
      },
    };
  }
  const candidates = hits.map((photo) => {
    const downloadUrl = photo.largeImageURL ?? photo.webformatURL ?? "";
    const metadata = String(photo.tags ?? "").trim();
    return {
      provider: "pixabay" as const,
      providerId: String(photo.id ?? ""),
      previewUrl: photo.webformatURL ?? downloadUrl,
      downloadUrl,
      metadata,
      score: curatorRelevanceScore(`${metadata} ${photo.pageURL ?? ""}`, plan),
      pageUrl: photo.pageURL?.trim() || null,
      query: plan.query,
    };
  }).filter((candidate) =>
    candidate.providerId && candidate.previewUrl && candidate.downloadUrl &&
    candidate.score !== null &&
    isAllowedProviderImageUrl("pixabay", candidate.downloadUrl)
  ).sort((left, right) => (right.score ?? 0) - (left.score ?? 0)).slice(0, 6)
    .map((candidate) => ({ ...candidate, score: candidate.score ?? 0 }));
  return {
    candidates,
    diagnostic: {
      status: candidates.length > 0 ? "ok" : "filtered_out",
      httpStatus: response.status,
      rawHitCount: hits.length,
      acceptedCount: candidates.length,
    },
  };
}

function logFoodVisualResolution(details: {
  provider: "pexels" | "pixabay";
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
    `provider: ${details.provider}`,
    `selected image id: ${details.imageId}`,
    `selected alt/description: ${details.description}`,
    `validation result: ${details.validationResult}`,
    "cached: false",
  ].join("\n"));
}

async function searchPexels(
  apiKey: string,
  foodKey: string,
  displayName: string,
): Promise<ProviderSelection | null> {
  const plan = searchPlanFor(foodKey, displayName);
  const url = new URL("https://api.pexels.com/v1/search");
  url.searchParams.set("query", plan.query);
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
      score: photoRelevanceScore(`${item.alt ?? ""} ${item.url ?? ""}`, plan),
    }))
    .filter((candidate) => {
      const source = candidate.item.src?.large2x ??
        candidate.item.src?.large ?? candidate.item.src?.original;
      return Boolean(source) && candidate.score !== null;
    })
    .sort((left, right) => (right.score ?? 0) - (left.score ?? 0))[0];
  if (!selected) {
    logFoodVisualResolution({
      provider: "pexels",
      foodKey,
      searchQuery: plan.query,
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
    provider: "pexels",
    foodKey,
    searchQuery: plan.query,
    imageId: String(photo.id ?? "unknown"),
    description: String(photo.alt ?? "none"),
    validationResult: `passed - relevance score ${selected.score}`,
  });

  return {
    imageUrl,
    imageId: String(photo.id ?? ""),
    pageUrl: photo.url?.trim() || null,
    query: plan.query,
    provider: "pexels",
  };
}

async function searchPixabay(
  apiKey: string,
  foodKey: string,
  displayName: string,
): Promise<ProviderSelection | null> {
  const plan = searchPlanFor(foodKey, displayName);
  const url = new URL("https://pixabay.com/api/");
  url.searchParams.set("key", apiKey);
  url.searchParams.set("q", plan.query);
  url.searchParams.set("image_type", "photo");
  url.searchParams.set("orientation", "horizontal");
  url.searchParams.set("safesearch", "true");
  url.searchParams.set("per_page", "20");

  const response = await fetch(url, { signal: AbortSignal.timeout(12000) });
  if (!response.ok) {
    throw new Error(`Pixabay search returned ${response.status}.`);
  }

  const payload = await response.json() as { hits?: PixabayPhoto[] };
  const selected = (payload.hits ?? [])
    .map((item) => ({
      item,
      score: photoRelevanceScore(
        `${item.tags ?? ""} ${item.pageURL ?? ""}`,
        plan,
      ),
    }))
    .filter((candidate) =>
      Boolean(candidate.item.largeImageURL ?? candidate.item.webformatURL) &&
      candidate.score !== null
    )
    .sort((left, right) => (right.score ?? 0) - (left.score ?? 0))[0];

  if (!selected) {
    logFoodVisualResolution({
      provider: "pixabay",
      foodKey,
      searchQuery: plan.query,
      imageId: "none",
      description: "none",
      validationResult: "failed - no relevant candidate",
    });
    return null;
  }

  logFoodVisualResolution({
    provider: "pixabay",
    foodKey,
    searchQuery: plan.query,
    imageId: String(selected.item.id ?? "unknown"),
    description: String(selected.item.tags ?? "none"),
    validationResult: `passed - relevance score ${selected.score}`,
  });
  return {
    imageUrl: selected.item.largeImageURL ?? selected.item.webformatURL!,
    imageId: String(selected.item.id ?? ""),
    pageUrl: selected.item.pageURL?.trim() || null,
    query: plan.query,
    provider: "pixabay",
  };
}

async function searchProviders(
  pexelsApiKey: string,
  pixabayApiKey: string,
  foodKey: string,
  displayName: string,
): Promise<ProviderSelection | null> {
  if (pexelsApiKey) {
    try {
      const selected = await searchPexels(pexelsApiKey, foodKey, displayName);
      if (selected) return selected;
    } catch (error) {
      console.error("Pexels ingredient search failed:", error);
    }
  }
  if (pixabayApiKey) {
    try {
      return await searchPixabay(pixabayApiKey, foodKey, displayName);
    } catch (error) {
      console.error("Pixabay ingredient search failed:", error);
    }
  }
  return null;
}

function curatorStatus(row: FoodVisualRow | null) {
  if (!row) return "uncurated";
  if (row.status === "missing") return "missing";
  if (row.status === "failed") return "failed";
  return row.source.startsWith("curated:") ? "approved" : "uncurated";
}

async function approveCuratorCandidate(
  admin: ReturnType<typeof createClient>,
  body: Record<string, unknown>,
  refreshKey: string,
) {
  const ingredientKey = String(body.ingredientKey ?? "").trim();
  const provider = String(body.provider ?? "").trim();
  const providerId = String(body.providerId ?? "").trim();
  const downloadUrl = String(body.downloadUrl ?? "").trim();
  const candidateToken = String(body.candidateToken ?? "").trim();
  if (!/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(ingredientKey) ||
    (provider !== "pexels" && provider !== "pixabay") || !providerId ||
    !downloadUrl || !candidateToken) {
    return jsonResponse({ error: "Invalid candidate approval request." }, 400);
  }

  const candidate = await verifyCandidate(candidateToken, refreshKey);
  if (!candidate || candidate.ingredientKey !== ingredientKey ||
    candidate.provider !== provider || candidate.providerId !== providerId ||
    candidate.downloadUrl !== downloadUrl ||
    !isAllowedProviderImageUrl(provider, downloadUrl)) {
    return jsonResponse({ error: "Candidate approval is invalid or expired." }, 400);
  }

  const current = await findCached(admin, ingredientKey);
  const imageResponse = await fetch(candidate.downloadUrl, {
    signal: AbortSignal.timeout(20000),
  });
  if (!imageResponse.ok) {
    return jsonResponse({ error: "Selected image download failed." }, 502);
  }
  const contentType = (imageResponse.headers.get("content-type") ?? "")
    .split(";")[0].trim().toLowerCase();
  if (contentType !== "image/jpeg") {
    return jsonResponse({ error: "Selected image is not a JPEG photo." }, 415);
  }
  const contentLength = Number(imageResponse.headers.get("content-length"));
  if (Number.isFinite(contentLength) && contentLength > 10485760) {
    return jsonResponse({ error: "Selected image size is invalid." }, 413);
  }
  const imageBytes = new Uint8Array(await imageResponse.arrayBuffer());
  if (imageBytes.byteLength === 0 || imageBytes.byteLength > 10485760) {
    return jsonResponse({ error: "Selected image size is invalid." }, 413);
  }

  const storagePath = `curated/${ingredientKey}_${Date.now()}.jpg`;
  const { error: uploadError } = await admin.storage.from(BUCKET).upload(
    storagePath,
    imageBytes,
    { contentType: "image/jpeg", cacheControl: "31536000", upsert: false },
  );
  if (uploadError) {
    return jsonResponse({ error: "Could not store the approved image." }, 502);
  }

  const { data: publicUrlData } = admin.storage.from(BUCKET).getPublicUrl(
    storagePath,
  );
  const row = {
    food_key: ingredientKey,
    display_name: displayNameForFood(ingredientKey.replaceAll("_", " ")),
    image_url: publicUrlData.publicUrl,
    storage_path: storagePath,
    source: `curated:${provider}`,
    status: "ready",
    fetched_at: new Date().toISOString(),
    retry_after: null,
    source_image_id: providerId,
    source_page_url: candidate.pageUrl,
    search_query: candidate.query,
  };
  const { data: saved, error: saveError } = await admin.from("food_visuals")
    .upsert(row, { onConflict: "food_key" })
    .select("food_key, display_name, image_url, storage_path, source, status, retry_after")
    .maybeSingle();
  if (saveError || !saved) {
    await admin.storage.from(BUCKET).remove([storagePath]);
    return jsonResponse({ error: "Could not save the approved image mapping." }, 502);
  }

  if (current?.storage_path && current.storage_path !== storagePath) {
    const { error: removeError } = await admin.storage.from(BUCKET).remove([
      current.storage_path,
    ]);
    if (removeError) {
      console.error("Old curated ingredient image cleanup failed:", removeError);
    }
  }
  return jsonResponse({
    ingredientKey,
    displayName: saved.display_name,
    imageUrl: saved.image_url,
    provider,
    providerId,
    status: "approved",
  });
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
  const pixabayApiKey = Deno.env.get("PIXABAY_API_KEY")?.trim() ?? "";
  const refreshKey = Deno.env.get("INGREDIENT_IMAGE_REFRESH_KEY")?.trim() ?? "";
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
  let forceRefresh = false;
  let previousStoragePath = "";

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });

  try {
    const body = await req.json() as Record<string, unknown>;
    const action = String(body.action ?? "resolve").trim().toLowerCase();

    if (action === "statuses") {
      const ingredientKeys = Array.isArray(body.ingredientKeys)
        ? body.ingredientKeys.map((value) => String(value).trim())
        : [];
      if (ingredientKeys.length === 0 || ingredientKeys.length > 200 ||
        ingredientKeys.some((key) =>
          !/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(key)
        )) {
        return jsonResponse({ error: "Valid ingredientKeys are required." }, 400);
      }
      const { data, error } = await admin.from("food_visuals")
        .select("food_key, display_name, image_url, storage_path, source, status, retry_after")
        .in("food_key", ingredientKeys);
      if (error) throw error;
      const rows = new Map(
        ((data ?? []) as FoodVisualRow[]).map((row) => [row.food_key, row]),
      );
      return jsonResponse({
        ingredients: ingredientKeys.map((key) => {
          const row = rows.get(key) ?? null;
          const status = curatorStatus(row);
          return {
            ingredientKey: key,
            status,
            imageUrl: row?.image_url ?? null,
            provider: row?.source.replace("curated:", "") ?? null,
          };
        }),
      });
    }

    if (action === "candidates") {
      const ingredientKey = String(body.ingredientKey ?? "").trim();
      if (!/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(ingredientKey)) {
        return jsonResponse({ error: "A valid ingredientKey is required." }, 400);
      }
      if (!refreshKey) {
        return jsonResponse({ error: "Candidate signing is not configured." }, 503);
      }
      const candidateDisplayName = displayNameForFood(
        ingredientKey.replaceAll("_", " "),
      );
      const pageNumber = (value: unknown) => {
        const parsed = Number(value ?? 1);
        return Number.isInteger(parsed) && parsed >= 1 && parsed <= 100
          ? parsed
          : 1;
      };
      const pexelsPage = pageNumber(body.pexelsPage);
      const pixabayPage = pageNumber(body.pixabayPage);
      const [pexels, pixabayResult] = await Promise.all([
        curatorPexelsCandidates(
          pexelsApiKey,
          ingredientKey,
          candidateDisplayName,
          pexelsPage,
        )
          .catch((error) => {
            console.error("Pexels curator search failed:", error);
            return [];
          }),
        curatorPixabayCandidates(
          pixabayApiKey,
          ingredientKey,
          candidateDisplayName,
          pixabayPage,
        )
          .catch(() => {
            console.error("Pixabay curator search failed.");
            return {
              candidates: [],
              diagnostic: {
                status: "http_error" as const,
                httpStatus: null,
                rawHitCount: 0,
                acceptedCount: 0,
              },
            };
          }),
      ]);
      const candidates = await Promise.all(
        [...pexels, ...pixabayResult.candidates].map(async (candidate) => ({
          provider: candidate.provider,
          providerId: candidate.providerId,
          previewUrl: candidate.previewUrl,
          downloadUrl: candidate.downloadUrl,
          metadata: candidate.metadata,
          score: candidate.score,
          candidateToken: await signCandidate(
            candidate,
            ingredientKey,
            refreshKey,
          ),
        })),
      );
      const current = await findCached(admin, ingredientKey);
      const currentStatus = curatorStatus(current);
      return jsonResponse({
        ingredientKey,
        current: {
          status: currentStatus,
          imageUrl: current?.image_url ?? null,
          provider: current?.source.replace("curated:", "") ?? null,
        },
        candidates,
        providerDiagnostics: {
          pixabay: pixabayResult.diagnostic,
        },
      });
    }

    if (action === "approve") {
      if (!refreshKey || req.headers.get("x-image-refresh-key") !== refreshKey) {
        return jsonResponse({ error: "Ingredient image approval is not authorized." }, 403);
      }
      return await approveCuratorCandidate(admin, body, refreshKey);
    }

    if (action !== "resolve") {
      return jsonResponse({ error: "Unsupported action." }, 400);
    }

    const requestedKey = String(
      body.ingredient_key ?? body.ingredientKey ?? "",
    ).trim();
    const foodName = String(body.food_name ?? "").trim() ||
      (requestedKey
        ? displayNameForFood(requestedKey.replaceAll("_", " "))
        : "");
    forceRefresh = body.force_refresh === true || body.forceRefresh === true;
    foodKey = requestedKey || normalizeFoodKey(foodName);
    displayName = displayNameForFood(foodName);

    if (!foodName || !foodKey || !/^[a-z0-9]+(?:_[a-z0-9]+)*$/.test(foodKey)) {
      return fallbackResponse(
        foodKey,
        displayName,
        "invalid_food_name",
        "food_name is required.",
        400,
      );
    }

    if (forceRefresh &&
      (!refreshKey || req.headers.get("x-image-refresh-key") !== refreshKey)) {
      return fallbackResponse(
        foodKey,
        displayName,
        "refresh_forbidden",
        "Ingredient image refresh is not authorized.",
        403,
      );
    }

    const cached = await findCached(admin, foodKey);
    previousStoragePath = cached?.storage_path ?? "";
    if (cached && !forceRefresh) {
      const retryAfter = cached.retry_after
        ? new Date(cached.retry_after).getTime()
        : Number.POSITIVE_INFINITY;
      if (cached.status === "ready" || retryAfter > Date.now()) {
        return cachedResponse(cached);
      }
    }

    if (!pexelsApiKey && !pixabayApiKey) {
      return fallbackResponse(
        foodKey,
        displayName,
        "image_provider_unavailable",
        "Ingredient imagery is temporarily unavailable.",
        503,
      );
    }

    const selected = await searchProviders(
      pexelsApiKey,
      pixabayApiKey,
      foodKey,
      displayName,
    );
    if (!selected) {
      if (forceRefresh && previousStoragePath) {
        await admin.storage.from(BUCKET).remove([previousStoragePath]);
      }
      await rememberFailure(admin, foodKey, displayName, "missing");
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

    storagePath = forceRefresh
      ? `foods/${foodKey}_${Date.now()}.jpg`
      : `foods/${foodKey}.jpg`;
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
      source: selected.provider,
      status: "ready",
      fetched_at: new Date().toISOString(),
      retry_after: null,
      source_image_id: selected.imageId || null,
      source_page_url: selected.pageUrl,
      search_query: selected.query,
    };
    const { data: inserted, error: insertError } = await admin
      .from("food_visuals")
      .upsert(row, { onConflict: "food_key" })
      .select("food_key, display_name, image_url, storage_path, source, status, retry_after")
      .maybeSingle();

    if (insertError) throw insertError;
    if (!inserted) {
      const concurrent = await waitForConcurrentCache(admin, foodKey);
      if (concurrent) return cachedResponse(concurrent);
      throw new Error("Could not finalize the ingredient image cache.");
    }

    if (forceRefresh && cached?.storage_path &&
      cached.storage_path !== storagePath) {
      await admin.storage.from(BUCKET).remove([cached.storage_path]);
    }

    return jsonResponse({
      food_key: inserted.food_key,
      display_name: inserted.display_name,
      image_url: inserted.image_url,
      source: selected.provider,
      cached: false,
    });
  } catch (error) {
    console.error("resolve-food-image error:", error);
    if (uploadedByThisRequest && storagePath) {
      await admin.storage.from(BUCKET).remove([storagePath]);
    }
    if (forceRefresh && previousStoragePath) {
      await admin.storage.from(BUCKET).remove([previousStoragePath]);
    }
    await rememberFailure(admin, foodKey, displayName, "failed");
    return fallbackResponse(
      foodKey,
      displayName,
      "food_visual_unavailable",
      "Ingredient imagery is temporarily unavailable.",
    );
  }
});
