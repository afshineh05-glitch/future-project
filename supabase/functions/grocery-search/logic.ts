export type PageEvidence = {
  productName: string;
  price: number | null;
  regularPrice: number | null;
  currency: string;
  packageQuantity: number | null;
  packageUnitType: "mass" | "volume" | "count" | null;
  availabilityVerified: boolean;
  saleEvidence: boolean;
  validUntil: Date | null;
  storeName: string | null;
  storePostalCode: string | null;
  locationEvidenceVerified: boolean;
  sourceUrl?: string;
  productId?: string | null;
};

export const PAGE_MAX_BYTES = 1_000_000;
export const PAGE_MAX_FETCHES = 5;
export const PAGE_TIMEOUT_MS = 4_000;

export function isAllowedRetailerUrl(value: string, domains: string[]) {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    return url.protocol === "https:" && !url.username && !url.password &&
      !url.port &&
      domains.some((domain) => host === domain || host.endsWith(`.${domain}`));
  } catch (_) {
    return false;
  }
}

export function isAllowedRedirect(value: string, domains: string[]) {
  return isAllowedRetailerUrl(value, domains);
}

const number = (value: unknown) => {
  const normalized = String(value ?? "").trim().replace(/,/g, "");
  const match = normalized.match(/\d+(?:\.\d+)?/);
  const parsed = Number(match?.[0] ?? "");
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

const text = (value: unknown) => typeof value === "string" ? value.trim() : "";

function explicitCadPrice(value: string) {
  const match = value.match(
    /(?:CAD\s*)?\$?\d+(?:[.,]\d{1,2})?\s*CAD|\$\d+(?:[.,]\d{1,2})?/i,
  );
  if (!match || !/CAD/i.test(match[0])) return null;
  return number(match[0]);
}

function packageInfo(value: string) {
  const match = value.match(
    /\b(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml|lb|oz|unit|units|ct|count|eggs?)\b/i,
  );
  if (!match) return { quantity: null, unitType: null } as const;
  const raw = Number(match[1].replace(",", "."));
  const unit = match[2].toLowerCase();
  if (!Number.isFinite(raw) || raw <= 0) {
    return { quantity: null, unitType: null } as const;
  }
  if (unit === "lb" || unit === "oz") {
    return { quantity: null, unitType: null } as const;
  }
  return {
    quantity: unit === "kg" || unit === "l" ? raw * 1000 : raw,
    unitType: unit === "l" || unit === "ml"
      ? "volume"
      : unit.match(/unit|ct|count|egg/)
      ? "count"
      : "mass",
  } as const;
}

const postal = (value: string) => {
  const match = value.toUpperCase().match(
    /\b[ABCEGHJKLMNPRSTVXY]\d[ABCEGHJKLMNPRSTVWXYZ][ -]?\d[ABCEGHJKLMNPRSTVWXYZ]\d\b/,
  );
  if (!match) return null;
  const compact = match[0].replace(/[ -]/g, "");
  return `${compact.slice(0, 3)} ${compact.slice(3)}`;
};

const date = (value: unknown) => {
  const parsed = new Date(String(value ?? ""));
  return Number.isFinite(parsed.getTime()) ? parsed : null;
};

function metaTags(html: string) {
  const values: Record<string, string> = {};
  for (const raw of html.matchAll(/<meta\s+([^>]+)>/gi)) {
    const attributes: Record<string, string> = {};
    for (const attribute of raw[1].matchAll(/([a-z:-]+)=["']([^"']*)["']/gi)) {
      attributes[attribute[1].toLowerCase()] = attribute[2].trim();
    }
    const key = attributes.property || attributes.name || attributes.itemprop;
    if (key && attributes.content) {
      values[key.toLowerCase()] = attributes.content;
    }
  }
  return values;
}

function jsonLdValues(html: string): unknown[] {
  const values: unknown[] = [];
  if (html.trimStart().startsWith("{") || html.trimStart().startsWith("[")) {
    try {
      values.push(JSON.parse(html));
      return values;
    } catch (_) {
      return values;
    }
  }
  for (
    const match of html.matchAll(
      /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi,
    )
  ) {
    try {
      const value = JSON.parse(match[1].trim());
      values.push(value);
    } catch (_) {
      // A malformed JSON-LD block is untrusted and ignored.
    }
  }
  return values;
}

function flatten(value: unknown): Record<string, unknown>[] {
  if (Array.isArray(value)) return value.flatMap(flatten);
  if (!value || typeof value !== "object") return [];
  const record = value as Record<string, unknown>;
  return [record, ...(record["@graph"] ? flatten(record["@graph"]) : [])];
}

export function parseRetailerPage(html: string): PageEvidence {
  const meta = metaTags(html);
  const blocks = jsonLdValues(html).flatMap(flatten);
  const product = blocks.find((item) => {
    const type = item["@type"];
    return type === "Product" ||
      (Array.isArray(type) && type.includes("Product"));
  }) ?? {};
  const offerValue = product.offers;
  const offer = (Array.isArray(offerValue) ? offerValue[0] : offerValue) as
    | Record<string, unknown>
    | undefined;
  const productName = text(product.name) || meta["og:title"] ||
    meta["product:name"];
  const offerPrice = number(offer?.price) ??
    number(meta["product:price:amount"]);
  const currency =
    (text(offer?.priceCurrency) || meta["product:price:currency"] || "")
      .toUpperCase();
  const priceSpecifications = offer?.priceSpecification;
  const listSpecification =
    (Array.isArray(priceSpecifications)
      ? priceSpecifications
      : [priceSpecifications])
      .filter((value): value is Record<string, unknown> =>
        Boolean(value && typeof value === "object")
      )
      .find((value) =>
        /list|regular/i.test(text(value.priceType) || text(value.name))
      );
  const regularPrice = number(offer?.listPrice) ??
    number(listSpecification?.price) ?? number(meta["product:price:regular"]);
  const weight = product.weight && typeof product.weight === "object"
    ? `${text((product.weight as Record<string, unknown>).value)} ${
      text((product.weight as Record<string, unknown>).unitCode)
    }`
    : text(product.weight);
  const packageData = packageInfo([
    productName,
    text(product.description),
    weight,
    text(product.size),
    meta["product:weight"] ?? "",
  ].join(" "));
  const availability = text(offer?.availability) ||
    meta["product:availability"];
  const validUntil = date(offer?.priceValidUntil) ??
    date(meta["product:price:valid_until"]);
  const seller = offer?.seller as Record<string, unknown> | undefined;
  const sellerAddress = seller?.address as Record<string, unknown> | undefined;
  const location = blocks.find((item) => {
    const type = item["@type"];
    return type === "LocalBusiness" || type === "GroceryStore" ||
      type === "Store" ||
      (Array.isArray(type) &&
        type.some((value) =>
          ["LocalBusiness", "GroceryStore", "Store"].includes(String(value))
        ));
  });
  const locationAddress = location?.address as
    | Record<string, unknown>
    | undefined;
  const sellerType = seller?.["@type"];
  const sellerIsStore = sellerType === "LocalBusiness" ||
    sellerType === "GroceryStore" || sellerType === "Store" ||
    (Array.isArray(sellerType) &&
      sellerType.some((value) =>
        ["LocalBusiness", "GroceryStore", "Store"].includes(String(value))
      ));
  const locationEvidenceVerified = Boolean(location || sellerIsStore);
  const addressText = location
    ? [locationAddress?.postalCode, locationAddress?.streetAddress]
      .filter(Boolean).join(" ")
    : sellerIsStore
    ? [sellerAddress?.postalCode, sellerAddress?.streetAddress]
      .filter(Boolean).join(" ")
    : "";
  const storePostalCode = postal(addressText);
  const storeName = text(location?.name) || text(seller?.name) ||
    text(meta["og:site_name"]) || null;
  const saleEvidence = Boolean(
    (regularPrice && offerPrice && regularPrice > offerPrice) ||
      /\b(on sale|sale price|special offer|save)\b/i.test(html),
  );
  return {
    productName,
    price: offerPrice,
    regularPrice,
    currency,
    packageQuantity: packageData.quantity,
    packageUnitType: packageData.unitType,
    availabilityVerified: /instock|in stock|limitedavailability|available/i
      .test(availability),
    saleEvidence,
    validUntil,
    storeName,
    storePostalCode,
    locationEvidenceVerified,
  };
}

export function parseSearchListing(
  item: Record<string, unknown>,
): PageEvidence {
  const title = text(item.title);
  const snippet = text(item.snippet);
  const price = explicitCadPrice(
    [title, snippet, text(item.price), text(item.currency)].join(" "),
  );
  return {
    productName: title,
    price,
    regularPrice: null,
    currency: price == null ? "" : "CAD",
    packageQuantity: packageInfo(title).quantity,
    packageUnitType: packageInfo(title).unitType,
    availabilityVerified: /\b(in stock|available|limited availability)\b/i.test(
      `${title} ${snippet}`,
    ),
    saleEvidence: /\b(on sale|sale price|special offer|save)\b/i.test(
      `${title} ${snippet}`,
    ),
    validUntil: null,
    storeName: null,
    storePostalCode: null,
    locationEvidenceVerified: false,
  };
}

export function parseShoppingListing(
  item: Record<string, unknown>,
): PageEvidence {
  const title = text(item.title);
  const delivery = text(item.delivery);
  const availability = text(item.availability);
  const packageData = packageInfo(title);
  const price = number(item.price);
  return {
    productName: title,
    price,
    regularPrice: null,
    currency: price == null ? "" : "CAD",
    packageQuantity: packageData.quantity,
    packageUnitType: packageData.unitType,
    availabilityVerified: /\b(in stock|available|limited availability)\b/i.test(
      availability,
    ),
    saleEvidence: /\b(on sale|sale price|special offer|save)\b/i.test(
      `${title} ${delivery}`,
    ),
    validUntil: null,
    storeName: text(item.source) || null,
    storePostalCode: postal(delivery),
    locationEvidenceVerified: false,
    sourceUrl: text(item.link),
    productId: text(item.productId) || null,
  };
}

const resolutionStopWords = new Set([
  "and",
  "the",
  "with",
  "for",
  "from",
  "canada",
  "organic",
  "natural",
  "brand",
  "pack",
  "case",
  "each",
  "size",
  "food",
  "foods",
  "grocery",
]);

const productTokens = (value: string) => [
  ...new Set(
    value.toLowerCase().replace(/[^a-z0-9]+/g, " ").split(/\s+/)
      .filter((token) =>
        token.length >= 3 && !/^\d+$/.test(token) &&
        !resolutionStopWords.has(token)
      ),
  ),
];

export type IngredientCategory =
  | "raw_protein"
  | "grain"
  | "legume"
  | "vegetable"
  | "fruit"
  | "oil_fat"
  | "dairy"
  | "other_basic";

const categoryTerms: Record<IngredientCategory, Set<string>> = {
  raw_protein: new Set([
    "chicken breast",
    "chicken thigh",
    "turkey breast",
    "lean beef",
    "ground beef",
    "steak",
  ]),
  grain: new Set(["white rice", "brown rice", "basmati rice", "oats", "pasta", "bread", "tortillas"]),
  legume: new Set(["lentils", "chickpeas", "black beans", "kidney beans"]),
  vegetable: new Set(["potatoes", "sweet potatoes"]),
  fruit: new Set(),
  oil_fat: new Set(["olive oil", "peanut butter"]),
  dairy: new Set(["milk", "skim milk", "cheese", "greek yogurt", "cottage cheese"]),
  other_basic: new Set(),
};

const normalizeProductText = (value: string) =>
  value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();

export function classifyIngredient(canonicalTerms: string[]): IngredientCategory {
  const canonical = normalizeProductText(canonicalTerms[0] ?? "");
  for (const category of Object.keys(categoryTerms) as IngredientCategory[]) {
    if (categoryTerms[category].has(canonical)) return category;
  }
  return "other_basic";
}

export function ingredientMatch(
  productText: string,
  canonicalTerms: string[],
) {
  const normalized = normalizeProductText(productText);
  const terms = canonicalTerms.map(normalizeProductText).filter(Boolean);
  const category = classifyIngredient(canonicalTerms);
  if (!terms.some((term) => normalized.includes(term))) {
    return { matches: false, category, quality: 0, reason: "missing_product" } as const;
  }
  if (category === "raw_protein") {
    const prepared = /\b(deli|cold cuts?|luncheon|sandwich(?: meat)?|ready to eat|prepared (?:meal|food)|meal kit|fully cooked|cooked|smoked|roasted|breaded|nuggets?|charcuterie|bbq|barbecue|skewers?)\b/.test(normalized);
    const slicedOrStrip = /\b(slices?|strips?)\b/.test(normalized);
    const explicitRaw = /\b(raw|uncooked|fresh|frozen)\b/.test(normalized);
    const explicitUncookedRoast = /\b(raw|uncooked)\b/.test(normalized);
    const ambiguousRoast = /\broast\b/.test(normalized) && !explicitUncookedRoast;
    if (prepared || slicedOrStrip || ambiguousRoast) {
      return {
        matches: false,
        category,
        quality: 0,
        reason: "processed_prepared_product",
      } as const;
    }
    const exact = terms.some((term) =>
      normalized === term ||
      new RegExp(`^${term.replace(/ /g, "\\s+")}\\s+\\d+(?:[.,]\\d+)?\\s*(?:g|kg|lb|oz)?$`).test(normalized)
    );
    return {
      matches: true,
      category,
      quality: exact ? 3 : explicitRaw ? 2 : 1,
      reason: null,
    } as const;
  }
  return { matches: true, category, quality: 1, reason: null } as const;
}

export function resolvedTitleMatchesShopping(
  shoppingTitle: string,
  resolvedText: string,
  canonicalTerms: string[],
) {
  const normalizedResolved = resolvedText.toLowerCase();
  if (!ingredientMatch(shoppingTitle, canonicalTerms).matches) return false;
  if (!ingredientMatch(resolvedText, canonicalTerms).matches) return false;
  const tokens = productTokens(shoppingTitle);
  if (tokens.length === 0) return false;
  const matches =
    tokens.filter((token) => normalizedResolved.includes(token)).length;
  return matches >= Math.min(2, Math.ceil(tokens.length * 0.4));
}

export function isLikelyProductDetailUrl(value: string) {
  try {
    const url = new URL(value);
    const path = url.pathname.toLowerCase().replace(/\/+$/, "");
    if (
      !path || path === "/" || url.searchParams.has("q") ||
      url.searchParams.has("query") || url.searchParams.has("search")
    ) return false;
    if (/\/(search|category|categories|collections|browse)(\/|$)/.test(path)) {
      return false;
    }
    return /\/(ip|product|products|p)(\/|\.|$)/.test(path) ||
      /\bproduct\b/.test(path) || /\d{7,}/.test(path);
  } catch (_) {
    return false;
  }
}

export function retailerDomainForShoppingSource(
  source: string,
  aliases: Record<string, string>,
) {
  const normalized = source.toLowerCase().replace(/[^a-z0-9]+/g, "");
  return aliases[normalized] ?? null;
}

export function rejectionReasons(
  evidence: PageEvidence,
  pass: "deal" | "regularPrice",
  canonicalTerms: string[],
  now = new Date(),
) {
  const reasons: string[] = [];
  const productMatch = ingredientMatch(evidence.productName, canonicalTerms);
  if (!productMatch.matches) reasons.push(productMatch.reason);
  if (!evidence.price || evidence.currency !== "CAD") {
    reasons.push("missing_price");
  }
  if (!evidence.storeName) reasons.push("missing_retailer");
  if (!evidence.packageQuantity || !evidence.packageUnitType) {
    reasons.push("missing_package");
  }
  if (!evidence.availabilityVerified) reasons.push("missing_availability");
  if (!evidence.storePostalCode || !evidence.locationEvidenceVerified) {
    reasons.push("missing_location");
  }
  if (pass === "deal") {
    if (!evidence.saleEvidence) reasons.push("missing_sale_evidence");
    if (evidence.validUntil && evidence.validUntil <= now) {
      reasons.push("stale_deal");
    }
  }
  return reasons;
}

export function blockingReasonsForOnline(reasons: string[]) {
  const optionalOnlineEvidence = new Set([
    "missing_package",
    "missing_availability",
    "missing_location",
  ]);
  return reasons.filter((reason) => !optionalOnlineEvidence.has(reason));
}

export function evidenceKey(evidence: PageEvidence) {
  let urlKey = "";
  try {
    const url = new URL(evidence.sourceUrl ?? "");
    urlKey = `${url.hostname.toLowerCase()}${url.pathname.replace(/\/$/, "")}`;
  } catch (_) {
    // A missing URL is handled by the caller's safety validation.
  }
  return [
    evidence.productId || urlKey || evidence.productName.toLowerCase(),
    evidence.price,
  ].join("|");
}

export function acceptUniqueEvidence(
  seen: Set<string>,
  evidence: PageEvidence,
) {
  const key = evidenceKey(evidence);
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
}

export function isPrivateOrReservedIp(host: string) {
  const value = host.toLowerCase().replace(/^\[|\]$/g, "");
  if (
    value === "localhost" || value.endsWith(".localhost") ||
    value.endsWith(".local")
  ) return true;
  if (value.includes(":")) {
    return value === "::1" || value.startsWith("fe8") ||
      value.startsWith("fe9") ||
      value.startsWith("fea") || value.startsWith("feb") ||
      value.startsWith("fc") ||
      value.startsWith("fd") || value.startsWith("::ffff:127.");
  }
  const parts = value.split(".").map(Number);
  if (
    parts.length !== 4 ||
    parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)
  ) return false;
  const [a, b] = parts;
  return a === 0 || a === 10 || a === 127 || a >= 224 ||
    (a === 100 && b >= 64 && b <= 127) || (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 0) ||
    (a === 192 && b === 168) || (a === 198 && (b === 18 || b === 19));
}
