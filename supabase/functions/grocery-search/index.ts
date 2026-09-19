import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  acceptUniqueEvidence,
  blockingReasonsForOnline,
  isLikelyProductDetailUrl,
  isPrivateOrReservedIp,
  PAGE_MAX_BYTES,
  PAGE_MAX_FETCHES,
  PAGE_TIMEOUT_MS,
  parseRetailerPage,
  parseSearchListing,
  parseShoppingListing,
  rejectionReasons,
  resolvedTitleMatchesShopping,
  retailerDomainForShoppingSource,
} from "./logic.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const foods: Record<string, string[]> = {
  chicken_breast: ["chicken breast"],
  chicken_thigh: ["chicken thigh"],
  turkey: ["turkey breast"],
  lean_beef: ["lean beef"],
  ground_beef: ["ground beef"],
  steak: ["steak"],
  salmon: ["salmon"],
  tuna: ["tuna"],
  shrimp: ["shrimp"],
  eggs: ["eggs"],
  egg_whites: ["egg whites"],
  greek_yogurt: ["greek yogurt"],
  cottage_cheese: ["cottage cheese"],
  tofu: ["tofu"],
  white_rice: ["white rice"],
  brown_rice: ["brown rice"],
  basmati_rice: ["basmati rice"],
  oats: ["oats"],
  pasta: ["pasta"],
  potatoes: ["potatoes"],
  sweet_potatoes: ["sweet potatoes"],
  bread: ["bread"],
  tortilla: ["tortillas"],
  milk: ["milk"],
  skim_milk: ["skim milk"],
  cheese: ["cheese"],
  lentils: ["lentils"],
  chickpeas: ["chickpeas"],
  black_beans: ["black beans"],
  kidney_beans: ["kidney beans"],
  peanut_butter: ["peanut butter"],
  olive_oil: ["olive oil"],
};

const postalPattern =
  /^[ABCEGHJKLMNPRSTVXY]\d[ABCEGHJKLMNPRSTVWXYZ] \d[ABCEGHJKLMNPRSTVWXYZ]\d$/;
const radii = new Set([2, 5, 10, 15, 25]);
const retailerDomains = [
  "metro.ca",
  "iga.net",
  "provigo.ca",
  "maxi.ca",
  "loblaws.ca",
  "nofrills.ca",
  "walmart.ca",
  "superc.ca",
  "foodbasics.ca",
  "sobeys.com",
  "safeway.ca",
  "costco.ca",
];
const retailerNames: Record<string, string> = {
  "metro.ca": "Metro",
  "iga.net": "IGA",
  "provigo.ca": "Provigo",
  "maxi.ca": "Maxi",
  "loblaws.ca": "Loblaws",
  "nofrills.ca": "No Frills",
  "walmart.ca": "Walmart",
  "superc.ca": "Super C",
  "foodbasics.ca": "Food Basics",
  "sobeys.com": "Sobeys",
  "safeway.ca": "Safeway",
  "costco.ca": "Costco",
};
const retailerSourceAliases: Record<string, string> = {
  metro: "metro.ca",
  metroca: "metro.ca",
  iga: "iga.net",
  iganet: "iga.net",
  provigo: "provigo.ca",
  provigoca: "provigo.ca",
  maxi: "maxi.ca",
  maxica: "maxi.ca",
  loblaws: "loblaws.ca",
  loblawsca: "loblaws.ca",
  nofrills: "nofrills.ca",
  nofrillsca: "nofrills.ca",
  walmart: "walmart.ca",
  walmartca: "walmart.ca",
  superc: "superc.ca",
  supercca: "superc.ca",
  foodbasics: "foodbasics.ca",
  foodbasicsca: "foodbasics.ca",
  sobeys: "sobeys.com",
  sobeyscom: "sobeys.com",
  safeway: "safeway.ca",
  safewayca: "safeway.ca",
  costco: "costco.ca",
  costcoca: "costco.ca",
  costcocanada: "costco.ca",
};
const MAX_MERCHANT_RESOLUTIONS = 5;
const isRetailerUrl = (value: string) => {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    return url.protocol === "https:" &&
      !url.username && !url.password &&
      !url.port &&
      retailerDomains.some((domain) =>
        host === domain || host.endsWith(`.${domain}`)
      );
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
  return typeof point?.lat === "number" && typeof point?.lng === "number"
    ? point
    : null;
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
    if (
      !isRetailerUrl(current.toString()) || !(await safeHost(current.hostname))
    ) {
      throw new Error("unsafe_url");
    }
    const abort = new AbortController();
    const timeout = setTimeout(() => abort.abort(), PAGE_TIMEOUT_MS);
    let response: Response;
    try {
      response = await fetch(current, {
        signal: abort.signal,
        redirect: "manual",
      });
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
    const contentType = (response.headers.get("content-type") ?? "")
      .toLowerCase();
    if (
      !contentType.includes("text/html") &&
      !contentType.includes("application/xhtml+xml") &&
      !contentType.includes("application/ld+json") &&
      !contentType.includes("application/json")
    ) {
      clearTimeout(timeout);
      throw new Error("unsupported_content_type");
    }
    const declaredLength = Number(
      response.headers.get("content-length") ?? "0",
    );
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

function km(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const r = 6371, rad = (x: number) => x * Math.PI / 180;
  const dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  const q = Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return r * 2 * Math.atan2(Math.sqrt(q), Math.sqrt(1 - q));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, {
      status: 405,
      headers: cors,
    });
  }
  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > 4096) {
    return Response.json({ error: "Request too large" }, {
      status: 413,
      headers: cors,
    });
  }
  const providerDiagnostics = {
    shoppingHttpStatus: null as number | null,
    shoppingResultsReceived: 0,
    shoppingResultsWithParsedCadPrice: 0,
    shoppingSourceNames: [] as string[],
    shoppingLinkHosts: {} as Record<string, number>,
    shoppingResultsWithOffers: 0,
    shoppingOfferFieldNames: [] as string[],
    organicFallbackRequested: false,
    shoppingReceived: 0,
    shoppingRelevant: 0,
    merchantResolutionAttempted: 0,
    merchantResolutionSucceeded: 0,
    merchantResolutionRejected: 0,
    acceptedShopping: 0,
    organicFallback: false,
  };
  try {
    const auth = req.headers.get("Authorization") ?? "";
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: auth } },
      },
    );
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return Response.json({ error: "Unauthorized" }, {
        status: 401,
        headers: cors,
      });
    }
    const body = await req.json();
    const terms = foods[String(body.foodId ?? "")];
    const postal = String(body.postalCode ?? "").toUpperCase().trim();
    const radius = Number(body.radiusKm);
    const neededQuantity = Number(body.neededQuantity);
    const pass = body.pass === "deal"
      ? "deal"
      : body.pass === "regularPrice"
      ? "regularPrice"
      : null;
    if (
      !terms || !postalPattern.test(postal) || !radii.has(radius) || !pass ||
      !Number.isFinite(neededQuantity) || neededQuantity < 1 ||
      neededQuantity > 100000
    ) {
      return Response.json({ error: "Invalid restricted search" }, {
        status: 400,
        headers: cors,
      });
    }
    const { data: area, error: areaError } = await supabase
      .from("user_shopping_areas")
      .select("postal_code,radius_km")
      .eq("user_id", user.id)
      .maybeSingle();
    if (
      areaError || !area || area.postal_code !== postal ||
      Number(area.radius_km) !== radius
    ) {
      return Response.json({ error: "Shopping area mismatch" }, {
        status: 403,
        headers: cors,
      });
    }
    const { data: allowed, error: rateError } = await supabase.rpc(
      "claim_grocery_search_request",
    );
    if (rateError || allowed !== true) {
      return Response.json({ error: "Rate limit exceeded" }, {
        status: 429,
        headers: cors,
      });
    }
    const apiKey = Deno.env.get("SERPER_API_KEY");
    const mapsKey = Deno.env.get("GOOGLE_MAPS_API_KEY");
    if (!apiKey) {
      return Response.json({ results: [], configured: false }, {
        headers: cors,
      });
    }
    const sites = retailerDomains.map((domain) => `site:${domain}`).join(
      " OR ",
    );
    const intent = pass === "deal"
      ? "sale flyer deal regular price valid until in stock"
      : "price CAD in stock";
    const query = `"${
      terms[0]
    }" ${intent} "${postal}" Montreal Quebec Canada (${sites}) -sponsored`;
    const serperRequest = async (path: "shopping" | "search", q: string) => {
      const response = await fetch(`https://google.serper.dev/${path}`, {
        method: "POST",
        headers: { "X-API-KEY": apiKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          q,
          gl: "ca",
          hl: "en",
          location: "Montreal, Quebec, Canada",
          num: 10,
        }),
      });
      if (path === "shopping") {
        providerDiagnostics.shoppingHttpStatus = response.status;
      }
      if (!response.ok) throw new Error(`Search provider ${response.status}`);
      const payload = await response.json() as Record<string, unknown>;
      if (path === "shopping") {
        const shopping = Array.isArray(payload.shopping)
          ? payload.shopping
          : [];
        providerDiagnostics.shoppingResultsReceived = shopping.length;
        providerDiagnostics.shoppingReceived = shopping.length;
        providerDiagnostics.shoppingResultsWithParsedCadPrice = shopping
          .filter((item) =>
            item && typeof item === "object" &&
            parseShoppingListing(item as Record<string, unknown>).price != null
          ).length;
        const sources = new Set<string>();
        const offerFields = new Set<string>();
        for (const raw of shopping) {
          if (!raw || typeof raw !== "object") continue;
          const item = raw as Record<string, unknown>;
          if (typeof item.source === "string" && item.source.trim()) {
            sources.add(item.source.trim());
          }
          try {
            const host = new URL(String(item.link ?? "")).hostname
              .toLowerCase();
            if (host) {
              providerDiagnostics.shoppingLinkHosts[host] =
                (providerDiagnostics.shoppingLinkHosts[host] ?? 0) + 1;
            }
          } catch (_) {
            // Invalid links are counted by normal rejection handling.
          }
          if (Array.isArray(item.offers)) {
            providerDiagnostics.shoppingResultsWithOffers++;
            for (const offer of item.offers) {
              if (!offer || typeof offer !== "object") continue;
              for (const key of Object.keys(offer as Record<string, unknown>)) {
                offerFields.add(key);
              }
            }
          }
        }
        providerDiagnostics.shoppingSourceNames = [...sources].sort();
        providerDiagnostics.shoppingOfferFieldNames = [...offerFields].sort();
      }
      return payload;
    };
    const origin = mapsKey ? await geocode(postal, mapsKey) : null;
    if (pass === "deal" && !origin) {
      return Response.json({ results: [] }, { headers: cors });
    }
    const results: Record<string, unknown>[] = [];
    const seen = new Set<string>();
    const rejected: Record<string, number> = {};
    const onlineOnly: Record<string, number> = {};
    const discovery = { shopping: 0, organicFallback: 0 };
    let fetchedPages = 0;
    const reject = (reason: string) => {
      rejected[reason] = (rejected[reason] ?? 0) + 1;
    };
    const collect = async (
      rawItems: unknown[],
      source: "shopping" | "organicFallback",
    ) => {
      for (const raw of rawItems) {
        if (!raw || typeof raw !== "object") continue;
        const item = raw as Record<string, unknown>;
        const sourceUrl = String(item.link ?? "");
        const retailer = retailerForUrl(sourceUrl);
        if (!retailer || !isRetailerUrl(sourceUrl)) continue;
        const listingEvidence = source === "shopping"
          ? parseShoppingListing(item)
          : parseSearchListing(item);
        listingEvidence.sourceUrl = sourceUrl;
        if (!listingEvidence.storeName) {
          listingEvidence.storeName = retailer.name;
        }
        let html: string;
        let evidence = listingEvidence;
        try {
          if (fetchedPages >= PAGE_MAX_FETCHES) {
            throw new Error("enrichment_limit");
          }
          fetchedPages++;
          html = await fetchRetailerPage(sourceUrl);
          const pageEvidence = parseRetailerPage(html);
          evidence = {
            ...listingEvidence,
            productName: pageEvidence.productName ||
              listingEvidence.productName,
            price: source === "shopping"
              ? listingEvidence.price
              : pageEvidence.price ?? listingEvidence.price,
            currency: source === "shopping"
              ? listingEvidence.currency
              : pageEvidence.currency || listingEvidence.currency,
            packageQuantity: pageEvidence.packageQuantity ??
              listingEvidence.packageQuantity,
            packageUnitType: pageEvidence.packageUnitType ??
              listingEvidence.packageUnitType,
            availabilityVerified: pageEvidence.availabilityVerified ||
              listingEvidence.availabilityVerified,
            saleEvidence: pageEvidence.saleEvidence ||
              listingEvidence.saleEvidence,
            validUntil: pageEvidence.validUntil ?? listingEvidence.validUntil,
            storeName: pageEvidence.storeName || listingEvidence.storeName,
            storePostalCode: pageEvidence.storePostalCode ??
              listingEvidence.storePostalCode,
          };
        } catch (error) {
          if (
            error instanceof Error &&
            (error.message === "unsafe_url" ||
              error.message === "unsafe_redirect")
          ) {
            reject(error.message);
            continue;
          }
          if (listingEvidence.price == null) {
            reject(
              error instanceof Error && error.message === "response_too_large"
                ? "response_too_large"
                : "fetch_failed",
            );
            continue;
          }
        }
        const reasons = rejectionReasons(evidence, pass, terms);
        const blockingReasons = blockingReasonsForOnline(reasons);
        if (blockingReasons.length > 0) {
          for (const reason of blockingReasons) reject(reason);
          continue;
        }
        if (reasons.includes("missing_package")) {
          onlineOnly.missing_package = (onlineOnly.missing_package ?? 0) + 1;
        }
        if (reasons.includes("missing_availability")) {
          onlineOnly.missing_availability =
            (onlineOnly.missing_availability ?? 0) + 1;
        }
        if (reasons.includes("missing_location")) {
          onlineOnly.missing_location = (onlineOnly.missing_location ?? 0) + 1;
        }
        if (!acceptUniqueEvidence(seen, evidence)) {
          reject("duplicate");
          continue;
        }
        const storePostal = evidence.storePostalCode;
        const validUntil = evidence.validUntil;
        let distanceKm: number | null = null;
        if (storePostal && origin && mapsKey) {
          const destination = await geocode(storePostal, mapsKey);
          if (destination) {
            const candidateDistance = km(origin, destination);
            if (candidateDistance <= radius) {
              distanceKm = candidateDistance;
            } else {
              onlineOnly.outside_radius = (onlineOnly.outside_radius ?? 0) + 1;
            }
          } else {
            onlineOnly.missing_location = (onlineOnly.missing_location ?? 0) +
              1;
          }
        }
        results.push({
          id: sourceUrl,
          productName: evidence.productName,
          storeName: evidence.storeName ?? retailer.name,
          storePostalCode: storePostal,
          distanceKm,
          price: evidence.price!,
          regularPrice: evidence.regularPrice,
          currency: "CAD",
          priceKind: pass === "deal" ? "sale" : "regular",
          packageQuantity: evidence.packageQuantity,
          packageUnitType: evidence.packageUnitType,
          validUntil: validUntil?.toISOString() ?? null,
          matchConfidence: 0.8,
          dealConfidence: pass === "deal" ? 0.8 : 1,
          sourceUrl,
          sourceName: new URL(sourceUrl).hostname.toLowerCase(),
          verifiedAt: new Date().toISOString(),
          availabilityVerified: evidence.availabilityVerified,
          packageConfirmed: evidence.packageQuantity != null &&
            evidence.packageUnitType != null,
          locationVerified: distanceKm != null,
          discoverySource: source === "shopping"
            ? "serper_shopping"
            : "serper_organic_fallback",
          sponsoredOnly: false,
        });
        discovery[source]++;
        if (source === "shopping") {
          providerDiagnostics.acceptedShopping++;
        }
      }
    };
    if (pass === "regularPrice") {
      const shoppingPayload = await serperRequest(
        "shopping",
        `${terms[0]} Montreal Canada`,
      );
      const shoppingItems = Array.isArray(shoppingPayload.shopping)
        ? shoppingPayload.shopping
        : [];
      const directItems: Record<string, unknown>[] = [];
      const resolutionCandidates: Array<{
        item: Record<string, unknown>;
        domain: string;
        retailerName: string;
      }> = [];
      const candidateKeys = new Set<string>();
      for (const raw of shoppingItems) {
        if (!raw || typeof raw !== "object") continue;
        const item = raw as Record<string, unknown>;
        const evidence = parseShoppingListing(item);
        const domain = retailerDomainForShoppingSource(
          String(item.source ?? ""),
          retailerSourceAliases,
        );
        if (!domain) continue;
        evidence.storeName = retailerNames[domain];
        const blocking = blockingReasonsForOnline(
          rejectionReasons(evidence, "regularPrice", terms),
        );
        if (blocking.length > 0) continue;
        const key = `${domain}|${
          evidence.productId ?? evidence.productName.toLowerCase()
        }|${evidence.price}`;
        if (candidateKeys.has(key)) continue;
        candidateKeys.add(key);
        providerDiagnostics.shoppingRelevant++;
        const sourceUrl = String(item.link ?? "");
        const directRetailer = retailerForUrl(sourceUrl);
        if (
          directRetailer?.domain === domain && isRetailerUrl(sourceUrl) &&
          isLikelyProductDetailUrl(sourceUrl)
        ) {
          directItems.push({ ...item, source: retailerNames[domain] });
        } else {
          resolutionCandidates.push({
            item,
            domain,
            retailerName: retailerNames[domain],
          });
        }
      }
      const selected: typeof resolutionCandidates = [];
      const selectedKeys = new Set<string>();
      const selectedDomains = new Set<string>();
      for (const candidate of resolutionCandidates) {
        if (selected.length >= MAX_MERCHANT_RESOLUTIONS) break;
        if (selectedDomains.has(candidate.domain)) continue;
        selected.push(candidate);
        selectedDomains.add(candidate.domain);
        selectedKeys.add(
          `${candidate.domain}|${
            String(candidate.item.productId ?? candidate.item.title)
          }`,
        );
      }
      for (const candidate of resolutionCandidates) {
        if (selected.length >= MAX_MERCHANT_RESOLUTIONS) break;
        const key = `${candidate.domain}|${
          String(candidate.item.productId ?? candidate.item.title)
        }`;
        if (selectedKeys.has(key)) continue;
        selected.push(candidate);
        selectedKeys.add(key);
      }
      const resolvedItems: Record<string, unknown>[] = [];
      for (const candidate of selected) {
        providerDiagnostics.merchantResolutionAttempted++;
        const title = String(candidate.item.title ?? "");
        const resolution = await serperRequest(
          "search",
          `site:${candidate.domain} "${title}"`,
        );
        const organic = Array.isArray(resolution.organic)
          ? resolution.organic
          : [];
        let resolvedUrl: string | null = null;
        for (const raw of organic) {
          if (!raw || typeof raw !== "object") continue;
          const result = raw as Record<string, unknown>;
          const url = String(result.link ?? "");
          const retailer = retailerForUrl(url);
          if (
            retailer?.domain !== candidate.domain || !isRetailerUrl(url) ||
            !isLikelyProductDetailUrl(url)
          ) continue;
          if (
            !resolvedTitleMatchesShopping(
              title,
              `${String(result.title ?? "")} ${String(result.snippet ?? "")}`,
              terms,
            )
          ) continue;
          resolvedUrl = url;
          break;
        }
        if (resolvedUrl) {
          providerDiagnostics.merchantResolutionSucceeded++;
          resolvedItems.push({
            ...candidate.item,
            link: resolvedUrl,
            source: candidate.retailerName,
          });
        } else {
          providerDiagnostics.merchantResolutionRejected++;
        }
      }
      await collect([...directItems, ...resolvedItems], "shopping");
      if (results.length === 0) {
        providerDiagnostics.organicFallbackRequested = true;
        providerDiagnostics.organicFallback = true;
        const fallbackPayload = await serperRequest("search", query);
        await collect(
          Array.isArray(fallbackPayload.organic) ? fallbackPayload.organic : [],
          "organicFallback",
        );
      }
    } else {
      // Verified Nearby Deals retain the existing strict organic/page-evidence path.
      const dealPayload = await serperRequest("search", query);
      await collect(
        Array.isArray(dealPayload.organic) ? dealPayload.organic : [],
        "organicFallback",
      );
    }
    return Response.json(
      {
        results,
        diagnostics: {
          fetchedPages,
          rejected,
          onlineOnly,
          discovery,
          providerDiagnostics,
        },
      },
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    const failure = /^Search provider \d+$/.test(message)
      ? "shopping_provider_http_error"
      : "shopping_pipeline_error";
    return Response.json(
      { results: [], diagnostics: { providerDiagnostics, failure } },
      { status: 200, headers: cors },
    );
  }
});
