import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const foods: Record<string, string[]> = {
  chicken_breast: ["chicken breast"], chicken_thigh: ["chicken thigh"],
  turkey: ["turkey breast"], lean_beef: ["lean beef"], ground_beef: ["ground beef"],
  steak: ["steak"], salmon: ["salmon"], tuna: ["tuna"], shrimp: ["shrimp"],
  eggs: ["eggs"], egg_whites: ["egg whites"], greek_yogurt: ["greek yogurt"],
  cottage_cheese: ["cottage cheese"], tofu: ["tofu"], white_rice: ["white rice"],
  brown_rice: ["brown rice"], basmati_rice: ["basmati rice"], oats: ["oats"],
  pasta: ["pasta"], potatoes: ["potatoes"], sweet_potatoes: ["sweet potatoes"],
  bread: ["bread"], tortilla: ["tortillas"], milk: ["milk"], skim_milk: ["skim milk"],
  cheese: ["cheese"], lentils: ["lentils"], chickpeas: ["chickpeas"],
  black_beans: ["black beans"], kidney_beans: ["kidney beans"],
  peanut_butter: ["peanut butter"], olive_oil: ["olive oil"],
};

const postalPattern = /^[ABCEGHJKLMNPRSTVXY]\d[ABCEGHJKLMNPRSTVWXYZ] \d[ABCEGHJKLMNPRSTVWXYZ]\d$/;
const radii = new Set([2, 5, 10, 15, 25]);
const retailerDomains = [
  "metro.ca", "iga.net", "provigo.ca", "maxi.ca", "loblaws.ca",
  "nofrills.ca", "walmart.ca", "superc.ca", "foodbasics.ca",
  "sobeys.com", "safeway.ca", "costco.ca",
];
const isRetailerUrl = (value: string) => {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    return url.protocol === "https:" &&
      !url.username && !url.password &&
      retailerDomains.some((domain) => host === domain || host.endsWith(`.${domain}`));
  } catch (_) {
    return false;
  }
};
const number = (v: unknown) => {
  const n = Number(String(v ?? "").replace(/[^0-9.]/g, ""));
  return Number.isFinite(n) && n > 0 ? n : null;
};
const first = (v: unknown) => Array.isArray(v) ? v[0] : v;

async function geocode(value: string, key: string) {
  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("address", `${value}, Canada`);
  url.searchParams.set("components", "country:CA");
  url.searchParams.set("key", key);
  const data = await (await fetch(url)).json();
  const point = data?.results?.[0]?.geometry?.location;
  return typeof point?.lat === "number" && typeof point?.lng === "number" ? point : null;
}

function km(a: {lat:number; lng:number}, b: {lat:number; lng:number}) {
  const r = 6371, rad = (x:number) => x * Math.PI / 180;
  const dLat = rad(b.lat-a.lat), dLng = rad(b.lng-a.lng);
  const q = Math.sin(dLat/2)**2 + Math.cos(rad(a.lat))*Math.cos(rad(b.lat))*Math.sin(dLng/2)**2;
  return r * 2 * Math.atan2(Math.sqrt(q), Math.sqrt(1-q));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: cors });
  }
  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > 4096) {
    return Response.json({ error: "Request too large" }, { status: 413, headers: cors });
  }
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: auth } },
    });
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return Response.json({ error: "Unauthorized" }, { status: 401, headers: cors });
    const body = await req.json();
    const terms = foods[String(body.foodId ?? "")];
    const postal = String(body.postalCode ?? "").toUpperCase().trim();
    const radius = Number(body.radiusKm);
    const neededQuantity = Number(body.neededQuantity);
    const pass = body.pass === "deal" ? "deal" : body.pass === "regularPrice" ? "regularPrice" : null;
    if (!terms || !postalPattern.test(postal) || !radii.has(radius) || !pass ||
      !Number.isFinite(neededQuantity) || neededQuantity < 1 || neededQuantity > 100000) {
      return Response.json({ error: "Invalid restricted search" }, { status: 400, headers: cors });
    }
    const { data: area, error: areaError } = await supabase
      .from("user_shopping_areas")
      .select("postal_code,radius_km")
      .eq("user_id", user.id)
      .maybeSingle();
    if (areaError || !area || area.postal_code !== postal || Number(area.radius_km) !== radius) {
      return Response.json({ error: "Shopping area mismatch" }, { status: 403, headers: cors });
    }
    const { data: allowed, error: rateError } = await supabase.rpc("claim_grocery_search_request");
    if (rateError || allowed !== true) {
      return Response.json({ error: "Rate limit exceeded" }, { status: 429, headers: cors });
    }
    const apiKey = Deno.env.get("GOOGLE_CSE_API_KEY");
    const cx = Deno.env.get("GOOGLE_CSE_CX");
    const mapsKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
    if (!apiKey || !cx || !mapsKey) return Response.json({ results: [], configured: false }, { headers: cors });
    const query = `"${terms[0]}" ${pass === "deal" ? "sale flyer" : "price"} grocery ${postal} Canada -sponsored`;
    const search = new URL("https://www.googleapis.com/customsearch/v1");
    search.searchParams.set("key", apiKey); search.searchParams.set("cx", cx);
    search.searchParams.set("q", query); search.searchParams.set("gl", "ca"); search.searchParams.set("cr", "countryCA");
    const response = await fetch(search);
    if (!response.ok) throw new Error(`Google search ${response.status}`);
    const payload = await response.json();
    const origin = await geocode(postal, mapsKey);
    if (!origin) return Response.json({ results: [] }, { headers: cors });
    const results = [];
    for (const item of payload.items ?? []) {
      const product = first(item.pagemap?.product);
      const offer = first(item.pagemap?.offer ?? product?.offers);
      const business = first(item.pagemap?.localbusiness ?? item.pagemap?.organization);
      const sourceUrl = String(item.link ?? "");
      const productName = String(product?.name ?? item.title ?? "");
      const lower = productName.toLowerCase();
      if (!terms.some((term) => lower.includes(term)) || !isRetailerUrl(sourceUrl)) continue;
      const price = number(offer?.price ?? product?.price);
      const regularPrice = number(offer?.highprice ?? offer?.listprice);
      const currency = String(offer?.pricecurrency ?? product?.pricecurrency ?? "").toUpperCase();
      const storeName = String(business?.name ?? offer?.seller?.name ?? "").trim();
      const storePostal = String(business?.postalcode ?? business?.address?.postalcode ?? "").toUpperCase().trim();
      const validUntil = offer?.validthrough ? new Date(offer.validthrough) : null;
      const availability = String(offer?.availability ?? "").toLowerCase();
      if (!price || currency !== "CAD" || !storeName || !postalPattern.test(storePostal)) continue;
      if (pass === "deal" && (!regularPrice || regularPrice <= price || !validUntil || !Number.isFinite(validUntil.getTime()))) continue;
      const destination = await geocode(storePostal, mapsKey);
      if (!destination) continue;
      const distanceKm = km(origin, destination);
      if (distanceKm > radius) continue;
      const packageMatch = productName.match(/(\d+(?:\.\d+)?)\s*(kg|g|l|ml)\b/i);
      const rawQty = packageMatch ? Number(packageMatch[1]) : null;
      const rawUnit = packageMatch?.[2]?.toLowerCase();
      const packageQuantity = rawQty == null ? null : (rawUnit === "kg" || rawUnit === "l") ? rawQty * 1000 : rawQty;
      const packageUnitType = rawUnit == null ? null : (rawUnit === "l" || rawUnit === "ml") ? "volume" : "mass";
      results.push({
        id: String(item.cacheId ?? sourceUrl), productName, storeName,
        storePostalCode: storePostal, distanceKm, price, regularPrice,
        currency: "CAD", priceKind: pass === "deal" ? "sale" : "regular",
        packageQuantity, packageUnitType,
        validUntil: validUntil?.toISOString() ?? null,
        matchConfidence: 0.9, dealConfidence: pass === "deal" ? 0.9 : 1,
        sourceUrl, sourceName: new URL(sourceUrl).hostname,
        verifiedAt: new Date().toISOString(),
        availabilityVerified: availability.includes("instock") || availability.includes("limitedavailability"),
        sponsoredOnly: false,
      });
    }
    return Response.json({ results }, { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (_) {
    return Response.json({ results: [] }, { status: 200, headers: cors });
  }
});
