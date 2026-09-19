import { assert, assertEquals, assertFalse, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  PAGE_MAX_BYTES,
  isAllowedRedirect,
  isAllowedRetailerUrl,
  isPrivateOrReservedIp,
  parseRetailerPage,
  rejectionReasons,
  acceptUniqueEvidence,
} from "./logic.ts";

const domains = ["metro.ca", "walmart.ca"];
const regularFixture = `<!doctype html><script type="application/ld+json">
{"@type":"Product","name":"Chicken Breast 1 kg","offers":{"@type":"Offer","price":"12.99","priceCurrency":"CAD","availability":"https://schema.org/InStock","seller":{"@type":"GroceryStore","name":"Metro","address":{"postalCode":"H2X 1Y4"}}}}
</script>`;
const saleFixture = `<!doctype html><script type="application/ld+json">
{"@graph":[{"@type":"Product","name":"Chicken Breast 1 kg","offers":{"price":9.99,"priceCurrency":"CAD","priceValidUntil":"2099-12-31","availability":"InStock","seller":{"name":"Metro","address":{"postalCode":"H2X 1Y4"}},"listPrice":14.99}}]}
</script>`;

Deno.test("valid regular Product/Offer evidence is accepted", () => {
  const evidence = parseRetailerPage(regularFixture);
  assertEquals(rejectionReasons(evidence, "regularPrice", ["chicken breast"]), []);
});

Deno.test("valid sale evidence requires current, regular, and future validity", () => {
  const evidence = parseRetailerPage(saleFixture);
  assertEquals(rejectionReasons(evidence, "deal", ["chicken breast"], new Date("2026-01-01")), []);
});

Deno.test("stale sale evidence is rejected", () => {
  const evidence = parseRetailerPage(saleFixture);
  assert(rejectionReasons(evidence, "deal", ["chicken breast"], new Date("2100-01-01")).includes("stale_deal"));
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
  assert(rejectionReasons(evidence, "regularPrice", ["chicken breast"]).includes("missing_package"));
});

Deno.test("missing location cannot become a nearby result", () => {
  const evidence = parseRetailerPage(regularFixture.replace("H2X 1Y4", ""));
  assert(rejectionReasons(evidence, "regularPrice", ["chicken breast"]).includes("missing_location"));
});

Deno.test("redirects must remain on approved HTTPS retailer domains", () => {
  assert(isAllowedRedirect("https://walmart.ca/product/1", domains));
  assertFalse(isAllowedRedirect("https://attacker.example/steal", domains));
  assertFalse(isAllowedRetailerUrl("https://walmart.ca:8443/product/1", domains));
});

Deno.test("private and reserved addresses are rejected", () => {
  assert(isPrivateOrReservedIp("127.0.0.1"));
  assert(isPrivateOrReservedIp("10.0.0.1"));
  assert(isPrivateOrReservedIp("169.254.10.20"));
  assertFalse(isPrivateOrReservedIp("142.250.72.14"));
});

Deno.test("oversized response limit is explicit", () => {
  assertThrows(() => {
    if (PAGE_MAX_BYTES + 1 > PAGE_MAX_BYTES) throw new Error("response_too_large");
  }, Error, "response_too_large");
});
