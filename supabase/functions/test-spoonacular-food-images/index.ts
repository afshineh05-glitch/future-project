import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TEST_FOODS = ["Turkey", "Lentils", "Olive Oil", "Oats"];
const SPOONACULAR_INGREDIENT_SEARCH_ENDPOINT =
  "https://api.spoonacular.com/food/ingredients/search";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type SpoonacularIngredient = {
  id?: number;
  name?: string;
  image?: string;
  aisle?: string;
  possibleUnits?: string[];
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalize(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replaceAll(/[^a-z0-9]+/g, " ")
    .replaceAll(/\s+/g, " ");
}

function singularize(value: string): string {
  return value
    .split(" ")
    .map((word) => word.endsWith("s") && !word.endsWith("ss")
      ? word.slice(0, -1)
      : word)
    .join(" ");
}

function matchScore(requestedName: string, matchedName: string): number {
  const requested = normalize(requestedName);
  const matched = normalize(matchedName);
  if (!matched) return -1;
  if (matched === requested) return 1000;
  if (singularize(matched) === singularize(requested)) return 950;

  const requestedWords = requested.split(" ");
  const matchedWords = new Set(matched.split(" "));
  const matchingWords = requestedWords.filter((word) => matchedWords.has(word));
  if (matchingWords.length === requestedWords.length) {
    return 800 - Math.abs(matched.length - requested.length);
  }
  if (matched.includes(requested) || requested.includes(matched)) {
    return 700 - Math.abs(matched.length - requested.length);
  }
  return matchingWords.length * 100 - Math.abs(matched.length - requested.length);
}

async function searchIngredient(apiKey: string, requestedName: string) {
  const url = new URL(SPOONACULAR_INGREDIENT_SEARCH_ENDPOINT);
  // Spoonacular's documented query parameter is case-sensitive: `apiKey`.
  // Never log `url`, because it contains the server-side secret.
  url.searchParams.set("apiKey", apiKey);
  url.searchParams.set("query", requestedName);
  url.searchParams.set("number", "10");
  url.searchParams.set("metaInformation", "true");

  console.log(
    `Spoonacular endpoint: ${SPOONACULAR_INGREDIENT_SEARCH_ENDPOINT}`,
  );
  const response = await fetch(url, {
    signal: AbortSignal.timeout(12000),
  });
  console.log(`Spoonacular HTTP status: ${response.status}`);
  if (!response.ok) {
    const failureBody = await response.text();
    const redactedFailureBody = failureBody.replaceAll(apiKey, "[REDACTED]");
    console.error(
      `Spoonacular failure response body: ${redactedFailureBody}`,
    );
    throw new Error(
      `Spoonacular ingredient search returned ${response.status}.`,
    );
  }

  const payload = await response.json() as {
    results?: SpoonacularIngredient[];
    totalResults?: number;
  };
  const ranked = (payload.results ?? [])
    .map((ingredient) => ({
      ingredient,
      score: matchScore(requestedName, String(ingredient.name ?? "")),
    }))
    .filter(({ ingredient, score }) =>
      score >= 0 && ingredient.id != null && Boolean(ingredient.image)
    )
    .sort((left, right) => right.score - left.score);
  const selected = ranked[0];
  if (!selected) {
    return {
      requested_food_name: requestedName,
      error: "No ingredient match with an image was found.",
      candidates_considered: payload.results?.length ?? 0,
    };
  }

  const ingredient = selected.ingredient;
  const imageFile = String(ingredient.image);
  return {
    requested_food_name: requestedName,
    ingredient_id: ingredient.id,
    matched_ingredient_name: ingredient.name,
    image_url: imageFile.startsWith("http")
      ? imageFile
      : `https://img.spoonacular.com/ingredients_500x500/${imageFile}`,
    match_metadata: {
      normalized_request: normalize(requestedName),
      normalized_match: normalize(String(ingredient.name)),
      exact_normalized_match:
        normalize(requestedName) === normalize(String(ingredient.name)),
      match_score: selected.score,
      aisle: ingredient.aisle ?? null,
      possible_units: ingredient.possibleUnits ?? [],
      image_file: imageFile,
      candidates_considered: payload.results?.length ?? 0,
      total_results: payload.totalResults ?? null,
    },
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
  const spoonacularApiKey =
    Deno.env.get("SPOONACULAR_API_KEY")?.trim() ?? "";
  const authorization = req.headers.get("Authorization") ?? "";

  console.log(
    `Spoonacular secret configured: ${spoonacularApiKey.length > 0}`,
  );
  if (!spoonacularApiKey) {
    return jsonResponse({
      error: "SPOONACULAR_API_KEY is missing or empty.",
    }, 500);
  }
  if (!supabaseUrl || !anonKey) {
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
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user?.id) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  try {
    const results = await Promise.all(
      TEST_FOODS.map((foodName) =>
        searchIngredient(spoonacularApiKey, foodName).catch((error) => ({
          requested_food_name: foodName,
          error: error instanceof Error ? error.message : String(error),
        }))
      ),
    );
    return jsonResponse({ provider: "spoonacular", results });
  } catch (error) {
    console.error("test-spoonacular-food-images error:", error);
    return jsonResponse({ error: "Spoonacular image test failed." }, 502);
  }
});
