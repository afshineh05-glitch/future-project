const FOOD_ALIASES: Readonly<Record<string, string>> = {
  grilled_chicken_breast: "chicken_breast",
  skinless_chicken_breast: "chicken_breast",
  boneless_chicken_breast: "chicken_breast",
  chicken_breasts: "chicken_breast",
  brown_rice: "rice_brown",
  whole_grain_rice: "rice_brown",
  greek_yogurt_0: "greek_yogurt",
  nonfat_greek_yogurt: "greek_yogurt",
  plain_greek_yogurt: "greek_yogurt",
  rolled_oats: "oats",
  old_fashioned_oats: "oats",
  whole_eggs: "eggs",
};

export function normalizeFoodKey(value: string): string {
  const normalized = value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "");

  return FOOD_ALIASES[normalized] ?? normalized;
}

export function displayNameForFood(value: string): string {
  return value
    .trim()
    .replace(/\s+/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export function foodAliasEntries(): ReadonlyArray<readonly [string, string]> {
  return Object.entries(FOOD_ALIASES);
}
