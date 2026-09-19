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
const retailerNames: Record<string, string> = {
  "metro.ca": "Metro", "iga.net": "IGA", "provigo.ca": "Provigo",
  "maxi.ca": "Maxi", "loblaws.ca": "Loblaws", "nofrills.ca": "No Frills",
  "walmart.ca": "Walmart", "superc.ca": "Super C", "foodbasics.ca": "Food Basics",
  "sobeys.com": "Sobeys", "safeway.ca": "Safeway", "costco.ca": "Costco",
};
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
const retailerForUrl = (value: string) => {
  try {
    const host = new URL(value).hostname.toLowerCase();
    const domain = retailerDomains.find((candidate) =>
      host === candidate || host.endsWith(`.${candidate}`)
    );
    return domain ? { domain, name: retailerNames[domain] } : null;
  } catch (_) {
    return null;
  }
};

const textOf = (item: Record<string, unknown>) =>
  [item.title, item.snippet, item.date].filter((value) => typeof value === "string").join(" ");

function explicitPrice(text: string) {
  const cad = text.match(/(?:CAD\s*\$?\s*(\d{1,4}(?:[.,]\d{2})?)|\$\s*(\d{1,4}(?:[.,]\d{2})?)\s*CAD)\b/i);
  return cad ? number((cad[1] ?? cad[2]).replace(",", ".")) : null;
}

function explicitRegularPrice(text: string) {
  const match = text.match(/(?:regular(?:ly)?|was|reg\.?|list price)\s*(?:price)?\s*[:\-]?\s*(?:CAD\s*)?\$\s*(\d{1,4}(?:[.,]\d{2})?)/i);
  return match ? number(match[1].replace(",", ".")) : null;
}

function explicitPackage(text: string) {
  const match = text.match(/\b(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml)\b/i);
  if (!match) return null;
  const raw = Number(match[1].replace(",", "."));
  const unit = match[2].toLowerCase();
  if (!Number.isFinite(raw) || raw <= 0) return null;
  return {
    quantity: unit === "kg" || unit === "l" ? raw * 1000 : raw,
    unitType: unit === "l" || unit === "ml" ? "volume" : "mass",
  };
}

function explicitPostal(text: string) {
  const match = text.toUpperCase().match(/\b[ABCEGHJKLMNPRSTVXY]\d[ABCEGHJKLMNPRSTVWXYZ][ -]?\d[ABCEGHJKLMNPRSTVWXYZ]\d\b/);
  if (!match) return null;
  const compact = match[0].replace(/[ -]/g, "");
  return `${compact.slice(0, 3)} ${compact.slice(3)}`;
}

function explicitValidUntil(text: string) {
  const match = text.match(/(?:valid|ends?|until|through)\s+(?:on\s+)?([A-Z][a-z]{2,8}\.?\s+\d{1,2},?\s+20\d{2}|20\d{2}-\d{2}-\d{2})/);
  if (!match) return null;
  const date = new Date(match[1]);
  return Number.isFinite(date.getTime()) ? date : null;
}

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
    const apiKey = Deno.env.get("SERPER_API_KEY");
    const mapsKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
    if (!apiKey || !mapsKey) return Response.json({ results: [], configured: false }, { headers: cors });
    const sites = retailerDomains.map((domain) => `site:${domain}`).join(" OR ");
    const intent = pass === "deal" ? "sale flyer deal regular price valid until in stock" : "price CAD in stock";
    const query = `"${terms[0]}" ${intent} "${postal}" Montreal Quebec Canada (${sites}) -sponsored`;
    const response = await fetch("https://google.serper.dev/search", {
      method: "POST",
      headers: { "X-API-KEY": apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({ q: query, gl: "ca", hl: "en", location: "Montreal, Quebec, Canada", num: 10 }),
    });
    if (!response.ok) throw new Error(`Search provider ${response.status}`);
    const payload = await response.json();
    const origin = await geocode(postal, mapsKey);
    if (!origin) return Response.json({ results: [] }, { headers: cors });
    const results = [];
    for (const raw of payload.organic ?? []) {
      if (!raw || typeof raw !== "object") continue;
      const item = raw as Record<string, unknown>;
      const sourceUrl = String(item.link ?? "");
      const retailer = retailerForUrl(sourceUrl);
      if (!retailer || !isRetailerUrl(sourceUrl)) continue;
      const evidence = textOf(item);
      const productName = String(item.title ?? "").trim();
      const lower = productName.toLowerCase();
      const price = explicitPrice(evidence);
      const regularPrice = explicitRegularPrice(evidence);
      const storePostal = explicitPostal(evidence);
      const packageInfo = explicitPackage(evidence);
      const validUntil = explicitValidUntil(evidence);
      const availabilityVerified = /\b(in[ -]?stock|available (?:now|today|at))\b/i.test(evidence);
      if (!terms.some((term) => lower.includes(term)) || !price || !storePostal ||
        !packageInfo || !availabilityVerified || !/\b(CAD|Canada|Canadian|QC|Quebec|Montreal)\b/i.test(evidence)) continue;
      if (pass === "deal" && (!/\b(sale|deal|flyer|save)\b/i.test(evidence) ||
        !regularPrice || regularPrice <= price || !validUntil)) continue;
      const destination = await geocode(storePostal, mapsKey);
      if (!destination) continue;
      const distanceKm = km(origin, destination);
      if (distanceKm > radius) continue;
      results.push({
        id: sourceUrl, productName, storeName: retailer.name,
        storePostalCode: storePostal, distanceKm, price, regularPrice,
        currency: "CAD", priceKind: pass === "deal" ? "sale" : "regular",
        packageQuantity: packageInfo.quantity, packageUnitType: packageInfo.unitType,
        validUntil: validUntil?.toISOString() ?? null,
        matchConfidence: 0.8, dealConfidence: pass === "deal" ? 0.8 : 1,
        sourceUrl, sourceName: new URL(sourceUrl).hostname.toLowerCase(),
        verifiedAt: new Date().toISOString(),
        availabilityVerified,
        sponsoredOnly: false,
      });
    }
    return Response.json({ results }, { headers: { ...cors, "Content-Type": "application/json" } });
  } catch (_) {
    return Response.json({ results: [] }, { status: 200, headers: cors });
  }
});
