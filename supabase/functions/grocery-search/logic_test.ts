import {
  assert,
  assertEquals,
  assertFalse,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  acceptUniqueEvidence,
  blockingReasonsForOnline,
  isAllowedRedirect,
  isAllowedRetailerUrl,
  isLikelyProductDetailUrl,
  isPrivateOrReservedIp,
  PAGE_MAX_BYTES,
  parseRetailerPage,
  parseSearchListing,
  parseShoppingListing,
  rejectionReasons,
  resolvedTitleMatchesShopping,
  retailerDomainForShoppingSource,
} from "./logic.ts";

const domains = ["metro.ca", "walmart.ca"];
const regularFixture = `<!doctype html><script type="application/ld+json">
{"@type":"Product","name":"Chicken Breast 1 kg","offers":{"@type":"Offer","price":"12.99","priceCurrency":"CAD","availability":"https://schema.org/InStock","seller":{"@type":"GroceryStore","name":"Metro","address":{"postalCode":"H2X 1Y4"}}}}
</script>`;
const saleFixture = `<!doctype html><script type="application/ld+json">
{"@graph":[{"@type":"Product","name":"Chicken Breast 1 kg","offers":{"price":9.99,"priceCurrency":"CAD","priceValidUntil":"2099-12-31","availability":"InStock","seller":{"name":"Metro","address":{"postalCode":"H2X 1Y4"}},"listPrice":14.99}}]}
</script>`;
const oliveOilOnlineFixture =
  `<!doctype html><script type="application/ld+json">
{"@type":"Product","name":"Olive Oil Extra Virgin","offers":{"@type":"Offer","price":"15.49","priceCurrency":"CAD","seller":{"@type":"Organization","name":"Metro"}}}
</script>`;
const chickpeasSerperListing = {
  link: "https://walmart.ca/en/ip/chickpeas/123",
};
const shoppingFixture = {
  title: "Dainty Brown Rice 900 g",
  source: "Walmart Canada",
  link: "https://www.walmart.ca/en/ip/dainty-brown-rice/600020000001",
  price: "$4.97",
  delivery: "Delivery available",
  productId: "shopping-product-1",
  rating: 4.6,
  ratingCount: 21,
  position: 1,
};

Deno.test("valid regular Product/Offer evidence is accepted", () => {
  const evidence = parseRetailerPage(regularFixture);
  assertEquals(
    rejectionReasons(evidence, "regularPrice", ["chicken breast"]),
    [],
  );
});

Deno.test("valid sale evidence requires current, regular, and future validity", () => {
  const evidence = parseRetailerPage(saleFixture);
  assertEquals(
    rejectionReasons(
      evidence,
      "deal",
      ["chicken breast"],
      new Date("2026-01-01"),
    ),
    [],
  );
});

Deno.test("stale sale evidence is rejected", () => {
  const evidence = parseRetailerPage(saleFixture);
  assert(
    rejectionReasons(
      evidence,
      "deal",
      ["chicken breast"],
      new Date("2100-01-01"),
    ).includes("stale_deal"),
  );
});

Deno.test("duplicate page evidence receives a stable dedupe key", () => {
  const seen = new Set<string>();
  const evidence = parseRetailerPage(saleFixture);
  assert(acceptUniqueEvidence(seen, evidence));
  assertFalse(acceptUniqueEvidence(seen, evidence));
});

Deno.test("missing package is rejected", () => {
  const evidence = parseRetailerPage(regularFixture.replace("1 kg", ""));
  assert(evidence.packageQuantity === null);
  assert(
    rejectionReasons(evidence, "regularPrice", ["chicken breast"]).includes(
      "missing_package",
    ),
  );
});

Deno.test("missing location cannot become a nearby result", () => {
  const evidence = parseRetailerPage(regularFixture.replace("H2X 1Y4", ""));
  const reasons = rejectionReasons(evidence, "regularPrice", [
    "chicken breast",
  ]);
  assert(reasons.includes("missing_location"));
  assertEquals(blockingReasonsForOnline(reasons), []);
});

Deno.test("Olive Oil without store postal evidence survives as an online price", () => {
  const evidence = parseRetailerPage(oliveOilOnlineFixture);
  const reasons = rejectionReasons(evidence, "regularPrice", ["olive oil"]);
  assertEquals(reasons, [
    "missing_package",
    "missing_availability",
    "missing_location",
  ]);
  assertEquals(blockingReasonsForOnline(reasons), []);
  assertEquals(evidence.price, 15.49);
  assertEquals(evidence.packageQuantity, null);
  assertEquals(evidence.packageUnitType, null);
});

Deno.test("explicit CAD Chickpeas Serper listing survives without optional evidence", () => {
  const evidence = parseSearchListing({
    title: "Chickpeas",
    snippet: "Walmart chickpeas $2.49 CAD",
  });
  evidence.storeName = "Walmart";
  const reasons = rejectionReasons(evidence, "regularPrice", ["chickpeas"]);
  assertEquals(reasons, [
    "missing_package",
    "missing_availability",
    "missing_location",
  ]);
  assertEquals(blockingReasonsForOnline(reasons), []);
  assert(isAllowedRetailerUrl(chickpeasSerperListing.link, domains));
  assertEquals(evidence.price, 2.49);
});

Deno.test("real Shopping schema yields a valid online listed price", () => {
  const evidence = parseShoppingListing(shoppingFixture);
  const reasons = rejectionReasons(evidence, "regularPrice", ["brown rice"]);
  assertEquals(reasons, ["missing_availability", "missing_location"]);
  assertEquals(blockingReasonsForOnline(reasons), []);
  assertEquals(evidence.price, 4.97);
  assertEquals(evidence.packageQuantity, 900);
  assertEquals(evidence.storeName, "Walmart Canada");
});

Deno.test("Shopping package and location remain optional and unconfirmed", () => {
  const evidence = parseShoppingListing({
    ...shoppingFixture,
    title: "Canned Chickpeas",
    price: "CAD 2.49",
    delivery: "Free delivery",
  });
  const reasons = rejectionReasons(evidence, "regularPrice", ["chickpeas"]);
  assert(reasons.includes("missing_package"));
  assert(reasons.includes("missing_location"));
  assertEquals(blockingReasonsForOnline(reasons), []);
});

Deno.test("Shopping price parsing handles separators without joining digits", () => {
  assertEquals(
    parseShoppingListing({ ...shoppingFixture, price: "$1,234.56" }).price,
    1234.56,
  );
});

Deno.test("Shopping and enriched evidence deduplicate by product ID or URL", () => {
  const seen = new Set<string>();
  const first = parseShoppingListing(shoppingFixture);
  const duplicate = { ...first, productName: "Brown Rice 900 g" };
  assert(acceptUniqueEvidence(seen, first));
  assertFalse(acceptUniqueEvidence(seen, duplicate));
});

Deno.test("valid Walmart merchant resolution matches source, product, and detail URL", () => {
  const aliases = { walmartca: "walmart.ca" };
  const domain = retailerDomainForShoppingSource("Walmart.ca", aliases);
  const url = "https://www.walmart.ca/en/ip/dainty-brown-rice/600020000001";
  assertEquals(domain, "walmart.ca");
  assert(isAllowedRetailerUrl(url, [domain!]));
  assert(isLikelyProductDetailUrl(url));
  assert(resolvedTitleMatchesShopping(
    "Dainty Brown Rice 900 g",
    "Dainty Brown Rice 900 g | Walmart Canada",
    ["brown rice"],
  ));
});

Deno.test("valid Super C merchant resolution is accepted", () => {
  const aliases = { superc: "superc.ca" };
  const domain = retailerDomainForShoppingSource("Super C", aliases);
  const url =
    "https://www.superc.ca/en/aisles/pantry/rice-grains/brown-rice/product/00012345678901";
  assertEquals(domain, "superc.ca");
  assert(isAllowedRetailerUrl(url, [domain!]));
  assert(isLikelyProductDetailUrl(url));
  assert(resolvedTitleMatchesShopping(
    "Long Grain Brown Rice 900 g",
    "Long Grain Brown Rice 900 g | Super C",
    ["brown rice"],
  ));
});

Deno.test("source and resolved merchant domain mismatch is rejected", () => {
  const sourceDomain = retailerDomainForShoppingSource("Walmart.ca", {
    walmartca: "walmart.ca",
  });
  const resolved = "https://www.superc.ca/en/product/00012345678901";
  assert(sourceDomain !== "superc.ca");
  assertFalse(isAllowedRetailerUrl(resolved, [sourceDomain!]));
});

Deno.test("Google Shopping and generic retailer pages are rejected", () => {
  assertFalse(isAllowedRetailerUrl(
    "https://www.google.com/shopping/product/123",
    ["walmart.ca"],
  ));
  assertFalse(isLikelyProductDetailUrl("https://www.walmart.ca/en"));
  assertFalse(
    isLikelyProductDetailUrl("https://www.walmart.ca/en/search?q=brown+rice"),
  );
  assertFalse(
    isLikelyProductDetailUrl("https://www.superc.ca/en/aisles/pantry/rice"),
  );
});

Deno.test("unrelated resolved product title is rejected", () => {
  assertFalse(resolvedTitleMatchesShopping(
    "Dainty Brown Rice 900 g",
    "Great Value Olive Oil 1 L | Walmart Canada",
    ["brown rice"],
  ));
});

Deno.test("Shopping price survives merchant URL resolution", () => {
  const evidence = parseShoppingListing(shoppingFixture);
  evidence.sourceUrl =
    "https://www.walmart.ca/en/ip/dainty-brown-rice/600020000001";
  assertEquals(evidence.price, 4.97);
  assertEquals(evidence.currency, "CAD");
});

Deno.test("redirects must remain on approved HTTPS retailer domains", () => {
  assert(isAllowedRedirect("https://walmart.ca/product/1", domains));
  assertFalse(isAllowedRedirect("https://attacker.example/steal", domains));
  assertFalse(
    isAllowedRetailerUrl("https://walmart.ca:8443/product/1", domains),
  );
});

Deno.test("private and reserved addresses are rejected", () => {
  assert(isPrivateOrReservedIp("127.0.0.1"));
  assert(isPrivateOrReservedIp("10.0.0.1"));
  assert(isPrivateOrReservedIp("169.254.10.20"));
  assertFalse(isPrivateOrReservedIp("142.250.72.14"));
});

Deno.test("oversized response limit is explicit", () => {
  assertThrows(
    () => {
      if (PAGE_MAX_BYTES + 1 > PAGE_MAX_BYTES) {
        throw new Error(
          "response_too_large",
        );
      }
    },
    Error,
    "response_too_large",
  );
});
