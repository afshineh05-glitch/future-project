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
};

export const PAGE_MAX_BYTES = 1_000_000;
export const PAGE_MAX_FETCHES = 5;
export const PAGE_TIMEOUT_MS = 4_000;

export function isAllowedRetailerUrl(value: string, domains: string[]) {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    return url.protocol === "https:" && !url.username && !url.password && !url.port &&
      domains.some((domain) => host === domain || host.endsWith(`.${domain}`));
  } catch (_) {
    return false;
  }
}

export function isAllowedRedirect(value: string, domains: string[]) {
  return isAllowedRetailerUrl(value, domains);
}

const number = (value: unknown) => {
  const parsed = Number(String(value ?? "").replace(/[^0-9.]/g, ""));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

const text = (value: unknown) => typeof value === "string" ? value.trim() : "";

function packageInfo(value: string) {
  const match = value.match(/\b(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml|lb|oz|unit|units|ct|count|eggs?)\b/i);
  if (!match) return { quantity: null, unitType: null } as const;
  const raw = Number(match[1].replace(",", "."));
  const unit = match[2].toLowerCase();
  if (!Number.isFinite(raw) || raw <= 0) return { quantity: null, unitType: null } as const;
  if (unit === "lb" || unit === "oz") return { quantity: null, unitType: null } as const;
  return {
    quantity: unit === "kg" || unit === "l" ? raw * 1000 : raw,
    unitType: unit === "l" || unit === "ml" ? "volume" : unit.match(/unit|ct|count|egg/) ? "count" : "mass",
  } as const;
}

const postal = (value: string) => {
  const match = value.toUpperCase().match(/\b[ABCEGHJKLMNPRSTVXY]\d[ABCEGHJKLMNPRSTVWXYZ][ -]?\d[ABCEGHJKLMNPRSTVWXYZ]\d\b/);
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
    if (key && attributes.content) values[key.toLowerCase()] = attributes.content;
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
  for (const match of html.matchAll(/<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) {
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
    return type === "Product" || (Array.isArray(type) && type.includes("Product"));
  }) ?? {};
  const offerValue = product.offers;
  const offer = (Array.isArray(offerValue) ? offerValue[0] : offerValue) as Record<string, unknown> | undefined;
  const productName = text(product.name) || meta["og:title"] || meta["product:name"];
  const offerPrice = number(offer?.price) ?? number(meta["product:price:amount"]);
  const currency = (text(offer?.priceCurrency) || meta["product:price:currency"] || "").toUpperCase();
  const priceSpecifications = offer?.priceSpecification;
  const listSpecification = (Array.isArray(priceSpecifications) ? priceSpecifications : [priceSpecifications])
    .filter((value): value is Record<string, unknown> => Boolean(value && typeof value === "object"))
    .find((value) => /list|regular/i.test(text(value.priceType) || text(value.name)));
  const regularPrice = number(offer?.listPrice) ?? number(listSpecification?.price) ?? number(meta["product:price:regular"]);
  const weight = product.weight && typeof product.weight === "object"
    ? `${text((product.weight as Record<string, unknown>).value)} ${text((product.weight as Record<string, unknown>).unitCode)}`
    : text(product.weight);
  const packageData = packageInfo([
    productName,
    text(product.description),
    weight,
    text(product.size),
    meta["product:weight"] ?? "",
  ].join(" "));
  const availability = text(offer?.availability) || meta["product:availability"];
  const validUntil = date(offer?.priceValidUntil) ?? date(meta["product:price:valid_until"]);
  const seller = offer?.seller as Record<string, unknown> | undefined;
  const sellerAddress = seller?.address as Record<string, unknown> | undefined;
  const location = blocks.find((item) => {
    const type = item["@type"];
    return type === "LocalBusiness" || type === "GroceryStore" || type === "Store" ||
      (Array.isArray(type) && type.some((value) => ["LocalBusiness", "GroceryStore", "Store"].includes(String(value))));
  });
  const locationAddress = location?.address as Record<string, unknown> | undefined;
  const addressText = [
    locationAddress?.postalCode, sellerAddress?.postalCode, locationAddress?.streetAddress,
    sellerAddress?.streetAddress, meta["business:contact_data:postal_code"],
  ].filter(Boolean).join(" ");
  const storePostalCode = postal(addressText);
  const storeName = text(location?.name) || text(seller?.name) || text(meta["og:site_name"]) || null;
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
    availabilityVerified: /instock|in stock|limitedavailability|available/i.test(availability),
    saleEvidence,
    validUntil,
    storeName,
    storePostalCode,
  };
}

export function rejectionReasons(
  evidence: PageEvidence,
  pass: "deal" | "regularPrice",
  canonicalTerms: string[],
  now = new Date(),
) {
  const reasons: string[] = [];
  const name = evidence.productName.toLowerCase();
  if (!canonicalTerms.some((term) => name.includes(term))) reasons.push("missing_product");
  if (!evidence.price || evidence.currency !== "CAD") reasons.push("missing_price");
  if (!evidence.packageQuantity || !evidence.packageUnitType) reasons.push("missing_package");
  if (!evidence.availabilityVerified) reasons.push("missing_availability");
  if (!evidence.storePostalCode) reasons.push("missing_location");
  if (pass === "deal") {
    if (!evidence.saleEvidence) reasons.push("missing_sale_evidence");
    if (!evidence.regularPrice || evidence.regularPrice <= (evidence.price ?? 0)) reasons.push("missing_regular_price");
    if (!evidence.validUntil || evidence.validUntil <= now) reasons.push("stale_deal");
  }
  return reasons;
}

export function evidenceKey(evidence: PageEvidence) {
  return [
    evidence.productName.toLowerCase(), evidence.price, evidence.packageQuantity,
    evidence.storePostalCode,
  ].join("|");
}

export function acceptUniqueEvidence(seen: Set<string>, evidence: PageEvidence) {
  const key = evidenceKey(evidence);
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
}

export function isPrivateOrReservedIp(host: string) {
  const value = host.toLowerCase().replace(/^\[|\]$/g, "");
  if (value === "localhost" || value.endsWith(".localhost") || value.endsWith(".local")) return true;
  if (value.includes(":")) {
    return value === "::1" || value.startsWith("fe8") || value.startsWith("fe9") ||
      value.startsWith("fea") || value.startsWith("feb") || value.startsWith("fc") ||
      value.startsWith("fd") || value.startsWith("::ffff:127.");
  }
  const parts = value.split(".").map(Number);
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return false;
  const [a, b] = parts;
  return a === 0 || a === 10 || a === 127 || a >= 224 ||
    (a === 100 && b >= 64 && b <= 127) || (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 0) ||
    (a === 192 && b === 168) || (a === 198 && (b === 18 || b === 19));
}
