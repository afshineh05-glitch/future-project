import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CALCULATION_VERSION = "v1";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type JsonRecord = Record<string, unknown>;

type PerformanceFuel = {
  goal: string;
  calories: {
    target: number;
    range_min: number;
    range_max: number;
  };
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  fiber_g: number;
  hydration_l: number;
  micronutrient_focus: string[];
  why: string;
  calculation_version: string;
  generated_at: string;
  cached: boolean;
};

type FoodCategory = "protein" | "carb" | "fat" | "vegetable" | "fruit";
type FoodSource = {
  food_key: string;
  display_name: string;
  categories: FoodCategory[];
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  diets: string[];
  allergens: string[];
  min_g: number;
  max_g: number;
  step_g: number;
};

const FOOD_CATALOG: FoodSource[] = [
  { food_key: "chicken_breast", display_name: "Chicken Breast", categories: ["protein"], calories: 165, protein_g: 31, carbs_g: 0, fat_g: 3.6, diets: ["omnivore"], allergens: [], min_g: 80, max_g: 220, step_g: 10 },
  { food_key: "turkey", display_name: "Turkey", categories: ["protein"], calories: 135, protein_g: 29, carbs_g: 0, fat_g: 1.8, diets: ["omnivore"], allergens: [], min_g: 80, max_g: 220, step_g: 10 },
  { food_key: "lean_beef", display_name: "Lean Beef", categories: ["protein"], calories: 217, protein_g: 26, carbs_g: 0, fat_g: 12, diets: ["omnivore"], allergens: [], min_g: 80, max_g: 200, step_g: 10 },
  { food_key: "salmon", display_name: "Salmon", categories: ["protein"], calories: 208, protein_g: 20, carbs_g: 0, fat_g: 13, diets: ["omnivore", "pescatarian"], allergens: ["seafood"], min_g: 90, max_g: 200, step_g: 10 },
  { food_key: "tuna", display_name: "Tuna", categories: ["protein"], calories: 132, protein_g: 29, carbs_g: 0, fat_g: 1, diets: ["omnivore", "pescatarian"], allergens: ["seafood"], min_g: 80, max_g: 200, step_g: 10 },
  { food_key: "eggs", display_name: "Eggs", categories: ["protein", "fat"], calories: 143, protein_g: 13, carbs_g: 0.7, fat_g: 9.5, diets: ["omnivore", "pescatarian", "vegetarian"], allergens: ["eggs"], min_g: 50, max_g: 200, step_g: 50 },
  { food_key: "egg_whites", display_name: "Egg Whites", categories: ["protein"], calories: 52, protein_g: 11, carbs_g: 0.7, fat_g: 0.2, diets: ["omnivore", "pescatarian", "vegetarian"], allergens: ["eggs"], min_g: 100, max_g: 300, step_g: 25 },
  { food_key: "greek_yogurt", display_name: "Greek Yogurt", categories: ["protein"], calories: 73, protein_g: 10, carbs_g: 3.9, fat_g: 2, diets: ["omnivore", "pescatarian", "vegetarian"], allergens: ["dairy"], min_g: 100, max_g: 300, step_g: 25 },
  { food_key: "cottage_cheese", display_name: "Cottage Cheese", categories: ["protein"], calories: 98, protein_g: 11, carbs_g: 3.4, fat_g: 4.3, diets: ["omnivore", "pescatarian", "vegetarian"], allergens: ["dairy"], min_g: 100, max_g: 250, step_g: 25 },
  { food_key: "tofu", display_name: "Tofu", categories: ["protein"], calories: 144, protein_g: 17, carbs_g: 2.8, fat_g: 8.7, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 100, max_g: 250, step_g: 25 },
  { food_key: "tempeh", display_name: "Tempeh", categories: ["protein"], calories: 193, protein_g: 20, carbs_g: 7.6, fat_g: 11, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 200, step_g: 20 },
  { food_key: "lentils", display_name: "Lentils", categories: ["protein", "carb"], calories: 116, protein_g: 9, carbs_g: 20, fat_g: 0.4, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 100, max_g: 300, step_g: 25 },
  { food_key: "beans", display_name: "Beans", categories: ["protein", "carb"], calories: 127, protein_g: 8.7, carbs_g: 23, fat_g: 0.5, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 100, max_g: 300, step_g: 25 },
  { food_key: "rice", display_name: "Rice", categories: ["carb"], calories: 130, protein_g: 2.7, carbs_g: 28, fat_g: 0.3, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 300, step_g: 20 },
  { food_key: "rice_brown", display_name: "Brown Rice", categories: ["carb"], calories: 123, protein_g: 2.7, carbs_g: 26, fat_g: 1, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 300, step_g: 20 },
  { food_key: "potato", display_name: "Potato", categories: ["carb"], calories: 87, protein_g: 1.9, carbs_g: 20, fat_g: 0.1, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 120, max_g: 400, step_g: 20 },
  { food_key: "sweet_potato", display_name: "Sweet Potato", categories: ["carb"], calories: 90, protein_g: 2, carbs_g: 21, fat_g: 0.2, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 120, max_g: 350, step_g: 20 },
  { food_key: "oats", display_name: "Oats", categories: ["carb"], calories: 379, protein_g: 13, carbs_g: 68, fat_g: 6.5, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 30, max_g: 100, step_g: 10 },
  { food_key: "quinoa", display_name: "Quinoa", categories: ["carb"], calories: 120, protein_g: 4.4, carbs_g: 21, fat_g: 1.9, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 300, step_g: 20 },
  { food_key: "pasta", display_name: "Pasta", categories: ["carb"], calories: 158, protein_g: 5.8, carbs_g: 31, fat_g: 0.9, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: ["gluten"], min_g: 80, max_g: 250, step_g: 20 },
  { food_key: "whole_grain_bread", display_name: "Whole-grain Bread", categories: ["carb"], calories: 247, protein_g: 13, carbs_g: 41, fat_g: 4.2, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: ["gluten"], min_g: 30, max_g: 150, step_g: 30 },
  { food_key: "olive_oil", display_name: "Olive Oil", categories: ["fat"], calories: 884, protein_g: 0, carbs_g: 0, fat_g: 100, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 3, max_g: 15, step_g: 1 },
  { food_key: "avocado", display_name: "Avocado", categories: ["fat"], calories: 160, protein_g: 2, carbs_g: 8.5, fat_g: 15, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 30, max_g: 120, step_g: 10 },
  { food_key: "almonds", display_name: "Almonds", categories: ["fat"], calories: 579, protein_g: 21, carbs_g: 22, fat_g: 50, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: ["nuts"], min_g: 10, max_g: 35, step_g: 5 },
  { food_key: "walnuts", display_name: "Walnuts", categories: ["fat"], calories: 654, protein_g: 15, carbs_g: 14, fat_g: 65, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: ["nuts"], min_g: 10, max_g: 35, step_g: 5 },
  { food_key: "peanut_butter", display_name: "Peanut Butter", categories: ["fat"], calories: 588, protein_g: 25, carbs_g: 20, fat_g: 50, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: ["nuts"], min_g: 10, max_g: 35, step_g: 5 },
  { food_key: "seeds", display_name: "Seeds", categories: ["fat"], calories: 560, protein_g: 20, carbs_g: 18, fat_g: 47, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 10, max_g: 35, step_g: 5 },
  { food_key: "banana", display_name: "Banana", categories: ["fruit", "carb"], calories: 89, protein_g: 1.1, carbs_g: 23, fat_g: 0.3, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 180, step_g: 20 },
  { food_key: "berries", display_name: "Berries", categories: ["fruit", "carb"], calories: 50, protein_g: 0.7, carbs_g: 12, fat_g: 0.3, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 200, step_g: 20 },
  { food_key: "apple", display_name: "Apple", categories: ["fruit", "carb"], calories: 52, protein_g: 0.3, carbs_g: 14, fat_g: 0.2, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 100, max_g: 220, step_g: 20 },
  { food_key: "broccoli", display_name: "Broccoli", categories: ["vegetable"], calories: 35, protein_g: 2.4, carbs_g: 7.2, fat_g: 0.4, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 200, step_g: 20 },
  { food_key: "spinach", display_name: "Spinach", categories: ["vegetable"], calories: 23, protein_g: 2.9, carbs_g: 3.6, fat_g: 0.4, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 60, max_g: 180, step_g: 20 },
  { food_key: "mixed_vegetables", display_name: "Mixed Vegetables", categories: ["vegetable"], calories: 65, protein_g: 3, carbs_g: 12, fat_g: 0.5, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 220, step_g: 20 },
  { food_key: "green_beans", display_name: "Green Beans", categories: ["vegetable"], calories: 35, protein_g: 1.9, carbs_g: 7.9, fat_g: 0.3, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 220, step_g: 20 },
  { food_key: "mixed_salad", display_name: "Mixed Salad", categories: ["vegetable"], calories: 25, protein_g: 1.5, carbs_g: 4.5, fat_g: 0.3, diets: ["omnivore", "pescatarian", "vegetarian", "vegan"], allergens: [], min_g: 80, max_g: 220, step_g: 20 },
];

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function asRecord(value: unknown): JsonRecord {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as JsonRecord
    : {};
}

function asNumber(value: unknown): number | null {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.map((item) => String(item)) : [];
}

function normalize(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replaceAll(/[^a-z0-9]+/g, "_")
    .replaceAll(/^_+|_+$/g, "");
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function roundTo(value: number, increment: number): number {
  return Math.round(value / increment) * increment;
}

function nutritionFor(food: FoodSource, amountG: number) {
  const scale = amountG / 100;
  return {
    food_key: food.food_key,
    display_name: food.display_name,
    amount_g: amountG,
    calories: Math.round(food.calories * scale),
    protein_g: Math.round(food.protein_g * scale),
    carbs_g: Math.round(food.carbs_g * scale),
    fat_g: Math.round(food.fat_g * scale),
  };
}

function catalogMatchesProfile(food: FoodSource, profile: JsonRecord): boolean {
  const diet = normalize(profile["diet_type"]) || "omnivore";
  if (!food.diets.includes(diet)) return false;
  const allergies = asStringArray(profile["food_allergies"])
    .map(normalize)
    .filter((item) => item !== "none" && item !== "other");
  if (food.allergens.some((allergen) => allergies.includes(normalize(allergen)))) {
    return false;
  }
  const excluded = [
    ...asStringArray(profile["foods_to_avoid"]),
    ...asStringArray(profile["disliked_foods"]),
  ].map(normalize).filter(Boolean);
  const foodTerms = [food.food_key, normalize(food.display_name)];
  return !excluded.some((term) =>
    foodTerms.some((foodTerm) => foodTerm === term || foodTerm.includes(term) || term.includes(foodTerm))
  );
}

function catalogAlternative(food: FoodSource) {
  return {
    food_key: food.food_key,
    display_name: food.display_name,
    calories_per_100g: food.calories,
    protein_per_100g: food.protein_g,
    carbs_per_100g: food.carbs_g,
    fat_per_100g: food.fat_g,
    min_g: food.min_g,
    max_g: food.max_g,
    step_g: food.step_g,
  };
}

function mealCount(value: unknown): number {
  const parsed = Number(String(value ?? "").replaceAll(/[^0-9]/g, ""));
  return clamp(Number.isFinite(parsed) && parsed > 0 ? parsed : 3, 2, 5);
}

function amountRange(food: FoodSource): number[] {
  const values: number[] = [];
  for (let amount = food.min_g; amount <= food.max_g; amount += food.step_g) {
    values.push(amount);
  }
  return values;
}

function profilePreferencePenalty(food: FoodSource, profile: JsonRecord): number {
  let penalty = 0;
  const budget = normalize(profile["food_budget"]);
  if (budget === "budget_conscious" && [
    "salmon", "tuna", "lean_beef", "avocado", "almonds", "walnuts",
  ].includes(food.food_key)) penalty += 12;
  const maxMinutes = Number(String(profile["maximum_cooking_time"] ?? "30").replaceAll(/[^0-9]/g, "")) || 30;
  if (maxMinutes <= 15 && ["lentils", "beans", "rice_brown", "potato", "sweet_potato"].includes(food.food_key)) {
    penalty += 8;
  }
  const skill = normalize(profile["cooking_skill"]);
  if (skill === "beginner" && ["salmon", "lean_beef", "tempeh"].includes(food.food_key)) {
    penalty += 5;
  }
  return penalty;
}

function buildMeal(
  strategy: JsonRecord,
  profile: JsonRecord,
  consumed: { calories: number; protein_g: number; carbs_g: number; fat_g: number; entries: number },
  localHour: number,
) {
  const remaining = {
    calories: Math.max(0, Number(strategy["calories_target"]) - consumed.calories),
    protein_g: Math.max(0, Number(strategy["protein_g"]) - consumed.protein_g),
    carbs_g: Math.max(0, Number(strategy["carbs_g"]) - consumed.carbs_g),
    fat_g: Math.max(0, Number(strategy["fat_g"]) - consumed.fat_g),
  };
  const preferredMeals = mealCount(profile["meals_per_day"]);
  const byLog = Math.max(1, preferredMeals - consumed.entries);
  const wakingHoursLeft = clamp(22 - localHour, 1, 14);
  const byTime = Math.max(1, Math.ceil(wakingHoursLeft / (16 / preferredMeals)));
  const mealsRemaining = Math.max(1, Math.min(byLog, byTime, preferredMeals));
  const targetCalories = Math.round(clamp(
    remaining.calories / mealsRemaining,
    Math.min(250, remaining.calories || 250),
    850,
  ));
  const target = {
    calories: targetCalories,
    protein_g: Math.round(Math.min(remaining.protein_g, Math.max(20, remaining.protein_g / mealsRemaining))),
    carbs_g: Math.round(Math.min(remaining.carbs_g, remaining.carbs_g / mealsRemaining)),
    fat_g: Math.round(Math.min(remaining.fat_g, remaining.fat_g / mealsRemaining)),
  };

  const available = FOOD_CATALOG.filter((food) => catalogMatchesProfile(food, profile));
  const proteins = available.filter((food) => food.categories.includes("protein"));
  const carbs = available.filter((food) => food.categories.includes("carb"));
  const vegetables = available.filter((food) => food.categories.includes("vegetable"));
  const fats = available.filter((food) => food.categories.includes("fat"));
  if (!proteins.length || !carbs.length || !vegetables.length) {
    throw new Error("Nutrition Profile restrictions leave too few compatible foods to build a balanced meal.");
  }

  let best: { foods: ReturnType<typeof nutritionFor>[]; score: number } | null = null;
  for (const protein of proteins) {
    for (const proteinAmount of amountRange(protein)) {
      const proteinFood = nutritionFor(protein, proteinAmount);
      for (const carb of carbs) {
        if (carb.food_key === protein.food_key) continue;
        for (const carbAmount of amountRange(carb)) {
          const carbFood = nutritionFor(carb, carbAmount);
          for (const vegetable of vegetables) {
            const vegetableFood = nutritionFor(vegetable, 100);
            const base = [proteinFood, carbFood, vegetableFood];
            const baseTotals = base.reduce((sum, food) => ({
              calories: sum.calories + food.calories,
              protein_g: sum.protein_g + food.protein_g,
              carbs_g: sum.carbs_g + food.carbs_g,
              fat_g: sum.fat_g + food.fat_g,
            }), { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 });
            const fatGap = Math.max(0, target.fat_g - baseTotals.fat_g);
            const fatOptions: Array<ReturnType<typeof nutritionFor> | null> = [null];
            for (const fat of fats) {
              if (base.some((food) => food.food_key === fat.food_key)) continue;
              const grams = roundTo(clamp(fatGap / Math.max(fat.fat_g, 1) * 100, fat.min_g, fat.max_g), fat.step_g);
              fatOptions.push(nutritionFor(fat, grams));
            }
            for (const fatFood of fatOptions) {
              const foods = fatFood ? [...base, fatFood] : base;
              const totals = foods.reduce((sum, food) => ({
                calories: sum.calories + food.calories,
                protein_g: sum.protein_g + food.protein_g,
                carbs_g: sum.carbs_g + food.carbs_g,
                fat_g: sum.fat_g + food.fat_g,
              }), { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 });
              const score = Math.abs(totals.protein_g - target.protein_g) * 5 +
                Math.abs(totals.calories - target.calories) * 0.12 +
                Math.abs(totals.carbs_g - target.carbs_g) * 1.5 +
                Math.abs(totals.fat_g - target.fat_g) * 1.2 +
                (totals.calories > target.calories * 1.15 ? 100 : 0) +
                foods.reduce((sum, food) => {
                  const catalogFood = FOOD_CATALOG.find((item) => item.food_key === food.food_key);
                  return sum + (catalogFood ? profilePreferencePenalty(catalogFood, profile) : 0);
                }, 0);
              if (!best || score < best.score) best = { foods, score };
            }
          }
        }
      }
    }
  }
  if (!best) throw new Error("No compatible meal combination could be generated.");
  const totals = best.foods.reduce((sum, food) => ({
    calories: sum.calories + food.calories,
    protein_g: sum.protein_g + food.protein_g,
    carbs_g: sum.carbs_g + food.carbs_g,
    fat_g: sum.fat_g + food.fat_g,
  }), { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 });
  const normalizedGaps = [
    ["Protein", remaining.protein_g / Math.max(1, Number(strategy["protein_g"]))],
    ["Carbohydrate", remaining.carbs_g / Math.max(1, Number(strategy["carbs_g"]))],
    ["Fat", remaining.fat_g / Math.max(1, Number(strategy["fat_g"]))],
  ] as Array<[string, number]>;
  normalizedGaps.sort((a, b) => b[1] - a[1]);
  const outputFoods = best.foods.map((food, index) => {
    const catalogFood = available.find((item) => item.food_key === food.food_key);
    if (!catalogFood) throw new Error("A generated food is missing from the catalog.");
    const role: FoodCategory = index === 0
      ? "protein"
      : index === 1
      ? "carb"
      : index === 2
      ? "vegetable"
      : "fat";
    return {
      ...food,
      role,
      alternatives: available
        .filter((candidate) => candidate.categories.includes(role))
        .map(catalogAlternative),
    };
  });
  return {
    mode: "meal_builder",
    goal: String(strategy["goal"]),
    target,
    foods: outputFoods,
    totals,
    remaining_before_meal: remaining,
    reason: `${normalizedGaps[0][0]} is the largest remaining macro gap today.`,
    recovery_context: false,
    meals_remaining_estimate: mealsRemaining,
    calculation_version: "meal_builder_v1",
  };
}

function canonicalGoal(value: unknown): string {
  switch (normalize(value)) {
    case "lose_fat":
    case "fat_loss":
      return "fat_loss";
    case "build_muscle":
    case "muscle_gain":
      return "muscle_gain";
    case "athletic_performance":
      return "athletic_performance";
    case "improve_fitness":
      return "fitness";
    case "improve_health":
      return "health";
    case "maintain_weight":
    case "maintenance":
      return "maintenance";
    default:
      return "maintenance";
  }
}

function activityFactor(
  activityLevel: unknown,
  trainingDays: number,
  workoutIntensity: unknown,
): number {
  const activity = normalize(activityLevel);
  const base = activity === "lightly_active"
    ? 1.30
    : activity === "moderately_active"
    ? 1.40
    : activity === "very_active"
    ? 1.55
    : activity === "extremely_active"
    ? 1.70
    : 1.20;
  const intensity = normalize(workoutIntensity);
  const perTrainingDay = intensity === "very_hard"
    ? 0.030
    : intensity === "hard"
    ? 0.025
    : intensity === "moderate"
    ? 0.020
    : intensity === "light"
    ? 0.015
    : 0.010;
  return clamp(base + clamp(trainingDays, 0, 7) * perTrainingDay, 1.20, 1.90);
}

function goalCalories(
  goal: string,
  tdee: number,
  bmr: number,
  sex: string,
): number {
  const minimum = sex === "female" ? 1200 : sex === "male" ? 1500 : 1350;
  if (goal === "fat_loss") {
    return Math.max(tdee * 0.85, tdee - 500, bmr * 1.20, minimum);
  }
  if (goal === "muscle_gain") return Math.min(tdee * 1.08, tdee + 300);
  if (goal === "athletic_performance") return Math.min(tdee * 1.05, tdee + 250);
  if (goal === "fitness") return tdee * 1.02;
  return tdee;
}

function proteinMultiplier(goal: string): number {
  if (goal === "fat_loss") return 2.0;
  if (goal === "muscle_gain" || goal === "athletic_performance") return 1.8;
  if (goal === "fitness" || goal === "maintenance") return 1.6;
  return 1.4;
}

function micronutrientFocus(dietType: unknown): string[] {
  switch (normalize(dietType)) {
    case "vegan":
      return ["Vitamin B12", "Iron", "Calcium", "Iodine", "Omega-3", "Vitamin D"];
    case "vegetarian":
      return ["Vitamin B12", "Iron", "Calcium", "Omega-3", "Vitamin D"];
    case "pescatarian":
      return ["Vitamin D", "Iodine"];
    default:
      return [];
  }
}

function goalWhy(goal: string): string {
  if (goal === "fat_loss") {
    return "A controlled deficit supports fat loss while higher protein helps preserve lean mass.";
  }
  if (goal === "muscle_gain") {
    return "A controlled surplus, adequate protein, and training-supportive carbohydrates support muscle gain.";
  }
  if (goal === "athletic_performance") {
    return "A small energy buffer and ample carbohydrate support training output and recovery.";
  }
  if (goal === "fitness") {
    return "Energy is kept near maintenance with a small training allowance for consistent performance.";
  }
  if (goal === "health") {
    return "Energy is kept near maintenance with balanced macros, fiber, and hydration priorities.";
  }
  return "Energy is set near estimated maintenance with balanced macros for training and daily activity.";
}

async function fingerprint(value: JsonRecord): Promise<string> {
  const bytes = new TextEncoder().encode(JSON.stringify(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function calculatePerformanceFuel(
  foundation: JsonRecord,
  nutritionProfile: JsonRecord,
): Omit<PerformanceFuel, "generated_at" | "cached"> {
  const age = asNumber(foundation["age"]);
  const heightCm = asNumber(foundation["height_cm"]);
  const weightKg = asNumber(foundation["weight_kg"]);
  if (!age || !heightCm || !weightKg) {
    throw new Error("Foundation age, height, and weight are required.");
  }

  const sex = normalize(foundation["sex"]);
  const sexConstant = sex === "male" ? 5 : sex === "female" ? -161 : -78;
  const bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + sexConstant;
  const lifestyle = asRecord(foundation["lifestyle"]);
  const trainingDays = asNumber(foundation["training_days_per_week"]) ?? 0;
  const sessionMinutes = asNumber(foundation["session_duration_minutes"]) ?? 45;
  const factor = activityFactor(
    foundation["job_activity_level"] ?? lifestyle["activity"],
    trainingDays,
    lifestyle["workout_intensity"],
  );
  const tdee = bmr * factor;
  const goal = canonicalGoal(foundation["primary_goal"]);
  const calories = roundTo(goalCalories(goal, tdee, bmr, sex), 50);

  const targetWeight = asNumber(foundation["target_weight_kg"]);
  const plausibleTarget = targetWeight != null &&
      targetWeight >= weightKg * 0.70 && targetWeight <= weightKg * 1.30;
  const proteinReferenceWeight = plausibleTarget &&
      (goal === "fat_loss" || goal === "muscle_gain")
    ? (weightKg + (targetWeight ?? weightKg)) / 2
    : weightKg;
  const protein = roundTo(proteinReferenceWeight * proteinMultiplier(goal), 5);
  const fatFloor = weightKg * 0.8;
  const fatFromCalories = calories * 0.25 / 9;
  const fatCeiling = calories * 0.35 / 9;
  const fat = roundTo(clamp(Math.max(fatFloor, fatFromCalories), 40, fatCeiling), 5);
  const carbs = Math.max(0, roundTo((calories - protein * 4 - fat * 9) / 4, 5));
  const fiber = Math.round(clamp(calories / 1000 * 14, 25, 45));
  const weeklyTrainingHours = clamp(trainingDays, 0, 7) * sessionMinutes / 60;
  const hydration = Math.round(
    clamp(weightKg * 0.035 + weeklyTrainingHours / 7 * 0.4, 2.0, 5.0) * 10,
  ) / 10;
  const rangeHalfWidth = Math.max(100, roundTo(calories * 0.04, 50));

  return {
    goal,
    calories: {
      target: calories,
      range_min: calories - rangeHalfWidth,
      range_max: calories + rangeHalfWidth,
    },
    protein_g: protein,
    carbs_g: carbs,
    fat_g: fat,
    fiber_g: fiber,
    hydration_l: hydration,
    micronutrient_focus: micronutrientFocus(nutritionProfile["diet_type"]),
    why: goalWhy(goal),
    calculation_version: CALCULATION_VERSION,
  };
}

function rowResponse(row: JsonRecord, cached: boolean): PerformanceFuel {
  return {
    goal: String(row["goal"]),
    calories: {
      target: Number(row["calories_target"]),
      range_min: Number(row["calories_range_min"]),
      range_max: Number(row["calories_range_max"]),
    },
    protein_g: Number(row["protein_g"]),
    carbs_g: Number(row["carbs_g"]),
    fat_g: Number(row["fat_g"]),
    fiber_g: Number(row["fiber_g"]),
    hydration_l: Number(row["hydration_l"]),
    micronutrient_focus: asStringArray(row["micronutrient_focus"]),
    why: String(row["why"]),
    calculation_version: String(row["calculation_version"]),
    generated_at: String(row["generated_at"]),
    cached,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed." }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim() ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ?? "";
  const authorization = req.headers.get("Authorization") ?? "";
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "Server configuration is incomplete." }, 500);
  }
  if (!authorization.startsWith("Bearer ")) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user?.id) return jsonResponse({ error: "Unauthorized." }, 401);

  try {
    const body = await req.json() as JsonRecord;
    const mode = String(body["mode"] ?? "");
    if (mode !== "performance_fuel" && mode !== "meal_builder") {
      return jsonResponse({
        error: "Unsupported Nutrition Engine mode.",
      }, 400);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    });
    const userId = userData.user.id;

    if (mode === "meal_builder") {
      const offsetMinutes = clamp(
        asNumber(body["timezone_offset_minutes"]) ?? 0,
        -14 * 60,
        14 * 60,
      );
      const shiftedNow = new Date(Date.now() + offsetMinutes * 60_000);
      const localStartUtc = new Date(
        Date.UTC(
          shiftedNow.getUTCFullYear(),
          shiftedNow.getUTCMonth(),
          shiftedNow.getUTCDate(),
        ) - offsetMinutes * 60_000,
      );
      const localEndUtc = new Date(localStartUtc.getTime() + 86_400_000);
      const [strategyResult, profileResult, logsResult] = await Promise.all([
        admin.from("nutrition_strategies").select("*").eq("user_id", userId).maybeSingle(),
        admin.from("nutrition_profiles").select("*").eq("user_id", userId).maybeSingle(),
        admin.from("nutrition_food_logs")
          .select("calories, protein_g, carbs_g, fat_g")
          .eq("user_id", userId)
          .gte("consumed_at", localStartUtc.toISOString())
          .lt("consumed_at", localEndUtc.toISOString()),
      ]);
      if (strategyResult.error) throw strategyResult.error;
      if (profileResult.error) throw profileResult.error;
      if (logsResult.error) throw logsResult.error;
      if (!strategyResult.data) {
        return jsonResponse({ error: "Generate Performance Fuel before building a meal." }, 400);
      }
      if (!profileResult.data) {
        return jsonResponse({ error: "Complete Nutrition Profile before building a meal." }, 400);
      }
      const consumed = (logsResult.data ?? []).reduce(
        (sum, row) => ({
          calories: sum.calories + Number(row.calories ?? 0),
          protein_g: sum.protein_g + Number(row.protein_g ?? 0),
          carbs_g: sum.carbs_g + Number(row.carbs_g ?? 0),
          fat_g: sum.fat_g + Number(row.fat_g ?? 0),
          entries: sum.entries + 1,
        }),
        { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0, entries: 0 },
      );
      return jsonResponse(buildMeal(
        strategyResult.data as JsonRecord,
        profileResult.data as JsonRecord,
        consumed,
        shiftedNow.getUTCHours(),
      ));
    }

    const [foundationResult, profileResult] = await Promise.all([
      admin.from("user_foundations").select("*").eq("user_id", userId).maybeSingle(),
      admin.from("nutrition_profiles").select("*").eq("user_id", userId).maybeSingle(),
    ]);
    if (foundationResult.error) throw foundationResult.error;
    if (profileResult.error) throw profileResult.error;
    if (!foundationResult.data || foundationResult.data["is_completed"] !== true) {
      return jsonResponse({ error: "Complete My Foundation before calculating Performance Fuel." }, 400);
    }
    if (!profileResult.data) {
      return jsonResponse({ error: "Complete Nutrition Profile before calculating Performance Fuel." }, 400);
    }

    const foundation = foundationResult.data as JsonRecord;
    const profile = profileResult.data as JsonRecord;
    const lifestyle = asRecord(foundation["lifestyle"]);
    const inputContext: JsonRecord = {
      calculation_version: CALCULATION_VERSION,
      foundation: {
        age: foundation["age"],
        sex: foundation["sex"],
        height_cm: foundation["height_cm"],
        weight_kg: foundation["weight_kg"],
        target_weight_kg: foundation["target_weight_kg"],
        primary_goal: foundation["primary_goal"],
        job_activity_level: foundation["job_activity_level"],
        training_days_per_week: foundation["training_days_per_week"],
        session_duration_minutes: foundation["session_duration_minutes"],
        training_level: foundation["training_level"],
        workout_intensity: lifestyle["workout_intensity"],
      },
      nutrition_profile: {
        diet_type: profile["diet_type"],
        food_allergies: profile["food_allergies"],
        foods_to_avoid: profile["foods_to_avoid"],
        disliked_foods: profile["disliked_foods"],
        meals_per_day: profile["meals_per_day"],
        maximum_cooking_time: profile["maximum_cooking_time"],
        cooking_skill: profile["cooking_skill"],
        food_budget: profile["food_budget"],
      },
    };
    const inputFingerprint = await fingerprint(inputContext);
    const { data: cached, error: cacheError } = await admin
      .from("nutrition_strategies")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();
    if (cacheError) throw cacheError;
    if (cached && cached["calculation_version"] === CALCULATION_VERSION &&
      cached["input_fingerprint"] === inputFingerprint) {
      return jsonResponse(rowResponse(cached as JsonRecord, true));
    }

    const result = calculatePerformanceFuel(foundation, profile);
    const now = new Date().toISOString();
    const row = {
      user_id: userId,
      goal: result.goal,
      calories_target: result.calories.target,
      calories_range_min: result.calories.range_min,
      calories_range_max: result.calories.range_max,
      protein_g: result.protein_g,
      carbs_g: result.carbs_g,
      fat_g: result.fat_g,
      fiber_g: result.fiber_g,
      hydration_l: result.hydration_l,
      micronutrient_focus: result.micronutrient_focus,
      why: result.why,
      calculation_version: CALCULATION_VERSION,
      input_fingerprint: inputFingerprint,
      input_context: inputContext,
      generated_at: now,
      updated_at: now,
    };
    const { data: stored, error: storeError } = await admin
      .from("nutrition_strategies")
      .upsert(row, { onConflict: "user_id" })
      .select("*")
      .single();
    if (storeError) throw storeError;
    return jsonResponse(rowResponse(stored as JsonRecord, false));
  } catch (error) {
    console.error("nutrition-engine error:", error);
    return jsonResponse({
      error: error instanceof Error ? error.message : "Performance Fuel is temporarily unavailable.",
    }, 500);
  }
});
