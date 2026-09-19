import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  PAGE_MAX_BYTES,
  PAGE_MAX_FETCHES,
  PAGE_TIMEOUT_MS,
  isPrivateOrReservedIp,
  parseRetailerPage,
  rejectionReasons,
  acceptUniqueEvidence,
} from "./logic.ts";

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
      !url.port &&
      retailerDomains.some((domain) => host === domain || host.endsWith(`.${domain}`));
  } catch (_) {
    return false;
  }
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

async function geocode(value: string, key: string) {
  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("address", `${value}, Canada`);
  url.searchParams.set("components", "country:CA");
  url.searchParams.set("key", key);
  const data = await (await fetch(url)).json();
  const point = data?.results?.[0]?.geometry?.location;
  return typeof point?.lat === "number" && typeof point?.lng === "number" ? point : null;
}

async function safeHost(host: string) {
  if (isPrivateOrReservedIp(host)) return false;
  try {
    const addresses = await Promise.all([
      Deno.resolveDns(host, "A"),
      Deno.resolveDns(host, "AAAA").catch(() => [] as string[]),
    ]);
    return addresses.flat().every((address) => !isPrivateOrReservedIp(address));
  } catch (_) {
    return false;
  }
}

async function fetchRetailerPage(sourceUrl: string) {
  let current = new URL(sourceUrl);
  for (let redirect = 0; redirect <= 3; redirect++) {
    if (!isRetailerUrl(current.toString()) || !(await safeHost(current.hostname))) {
      throw new Error("unsafe_url");
    }
    const abort = new AbortController();
    const timeout = setTimeout(() => abort.abort(), PAGE_TIMEOUT_MS);
    let response: Response;
    try {
      response = await fetch(current, { signal: abort.signal, redirect: "manual" });
    } catch (error) {
      clearTimeout(timeout);
      throw error;
    }
    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      clearTimeout(timeout);
      if (!location || redirect === 3) throw new Error("unsafe_redirect");
      current = new URL(location, current);
      continue;
    }
    if (!response.ok) {
      clearTimeout(timeout);
      throw new Error("fetch_failed");
    }
    const contentType = (response.headers.get("content-type") ?? "").toLowerCase();
    if (!contentType.includes("text/html") && !contentType.includes("application/xhtml+xml") &&
      !contentType.includes("application/ld+json") && !contentType.includes("application/json")) {
      clearTimeout(timeout);
      throw new Error("unsupported_content_type");
    }
    const declaredLength = Number(response.headers.get("content-length") ?? "0");
    if (declaredLength > PAGE_MAX_BYTES) {
      clearTimeout(timeout);
      throw new Error("response_too_large");
    }
    if (!response.body) {
      clearTimeout(timeout);
      throw new Error("fetch_failed");
    }
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      total += part.value.byteLength;
      if (total > PAGE_MAX_BYTES) {
        clearTimeout(timeout);
        throw new Error("response_too_large");
      }
      chunks.push(part.value);
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    clearTimeout(timeout);
    return new TextDecoder().decode(bytes);
  }
  throw new Error("unsafe_redirect");
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
    const seen = new Set<string>();
    const rejected: Record<string, number> = {};
    let fetchedPages = 0;
    const reject = (reason: string) => {
      rejected[reason] = (rejected[reason] ?? 0) + 1;
    };
    for (const raw of payload.organic ?? []) {
      if (fetchedPages >= PAGE_MAX_FETCHES) break;
      if (!raw || typeof raw !== "object") continue;
      const item = raw as Record<string, unknown>;
      const sourceUrl = String(item.link ?? "");
      const retailer = retailerForUrl(sourceUrl);
      if (!retailer || !isRetailerUrl(sourceUrl)) continue;
      let html: string;
      try {
        fetchedPages++;
        html = await fetchRetailerPage(sourceUrl);
      } catch (error) {
        reject(error instanceof Error && error.message === "response_too_large" ? "response_too_large" : "fetch_failed");
        continue;
      }
      const evidence = parseRetailerPage(html);
      const reasons = rejectionReasons(evidence, pass, terms);
      if (reasons.length > 0) {
        for (const reason of reasons) reject(reason);
        continue;
      }
      if (!acceptUniqueEvidence(seen, evidence)) {
        reject("duplicate");
        continue;
      }
      const storePostal = evidence.storePostalCode!;
      const validUntil = evidence.validUntil;
      const destination = await geocode(storePostal, mapsKey);
      if (!destination) {
        reject("missing_location");
        continue;
      }
      const distanceKm = km(origin, destination);
      if (distanceKm > radius) {
        reject("outside_radius");
        continue;
      }
      results.push({
        id: sourceUrl, productName: evidence.productName, storeName: evidence.storeName ?? retailer.name,
        storePostalCode: storePostal, distanceKm, price: evidence.price!, regularPrice: evidence.regularPrice,
        currency: "CAD", priceKind: pass === "deal" ? "sale" : "regular",
        packageQuantity: evidence.packageQuantity, packageUnitType: evidence.packageUnitType,
        validUntil: validUntil?.toISOString() ?? null,
        matchConfidence: 0.8, dealConfidence: pass === "deal" ? 0.8 : 1,
        sourceUrl, sourceName: new URL(sourceUrl).hostname.toLowerCase(),
        verifiedAt: new Date().toISOString(),
        availabilityVerified: evidence.availabilityVerified,
        sponsoredOnly: false,
      });
    }
    return Response.json(
      { results, diagnostics: { fetchedPages, rejected } },
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (_) {
    return Response.json({ results: [] }, { status: 200, headers: cors });
  }
});
