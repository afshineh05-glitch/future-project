import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

function extractOutputText(data: any): string {
  if (typeof data?.output_text === "string") {
    return data.output_text.trim();
  }

  if (!Array.isArray(data?.output)) {
    return "";
  }

  const parts: string[] = [];

  for (const item of data.output) {
    if (item?.type !== "message" ||
        !Array.isArray(item?.content)) {
      continue;
    }

    for (const content of item.content) {
      if (
        content?.type === "output_text" &&
        typeof content?.text === "string"
      ) {
        parts.push(content.text);
      }
    }
  }

  return parts.join("\n").trim();
}

function asRecord(value: unknown): Record<string, unknown> {
  if (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value)
  ) {
    return value as Record<string, unknown>;
  }

  return {};
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];

  return value
    .filter((item) => item !== null && item !== undefined)
    .map((item) => String(item).trim())
    .filter(Boolean);
}

const CANONICAL_MUSCLES = [
  "chest",
  "front_delts",
  "side_delts",
  "rear_delts",
  "biceps",
  "triceps",
  "forearms",
  "lats",
  "upper_back",
  "traps",
  "lower_back",
  "core",
  "obliques",
  "glutes",
  "quads",
  "hamstrings",
  "adductors",
  "hip_flexors",
  "calves",
] as const;

type CanonicalMuscle =
  typeof CANONICAL_MUSCLES[number];

const CANONICAL_MUSCLE_SET =
  new Set<string>(CANONICAL_MUSCLES);

function normalizeCanonicalMuscles(
  value: unknown,
): CanonicalMuscle[] {
  if (!Array.isArray(value)) return [];

  const unique = new Set<CanonicalMuscle>();

  for (const item of value) {
    const muscle =
      String(item ?? "")
        .trim()
        .toLowerCase();

    if (CANONICAL_MUSCLE_SET.has(muscle)) {
      unique.add(muscle as CanonicalMuscle);
    }
  }

  return [...unique];
}

function clampTrainingDays(
  value: unknown,
): number {
  const parsed =
    typeof value === "number"
      ? Math.round(value)
      : Number.parseInt(String(value ?? ""), 10);

  if (!Number.isFinite(parsed)) return 3;

  return Math.max(1, Math.min(6, parsed));
}

function addDays(
  isoDate: string,
  days: number,
): string {
  const date = new Date(`${isoDate}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function normalizeLevel(value: unknown): string {
  const level = String(value ?? "").trim();

  if (
    level === "Beginner" ||
    level === "Intermediate" ||
    level === "Advanced"
  ) {
    return level;
  }

  return "Beginner";
}

function buildTrustedFoundation(
  row: Record<string, unknown>,
) {
  const lifestyle = asRecord(row["lifestyle"]);
  const nutrition = asRecord(row["nutrition"]);

  return {
    age: row["age"] ?? null,
    sex: row["sex"] ?? null,

    height_cm: row["height_cm"] ?? null,
    weight_kg: row["weight_kg"] ?? null,
    target_weight_kg:
      row["target_weight_kg"] ?? null,

    primary_goal:
      row["primary_goal"] ?? null,
    body_type:
      row["body_type"] ?? null,

    training_level:
      row["training_level"] ??
      lifestyle["experience"] ??
      null,

    training_days_per_week:
      row["training_days_per_week"] ??
      null,

    session_duration_minutes:
      row["session_duration_minutes"] ??
      null,

    training_location:
      row["training_location"] ??
      lifestyle["gym_access"] ??
      null,

    preferred_training_time:
      row["preferred_training_time"] ??
      lifestyle["workout_time"] ??
      null,

    equipment:
      asStringArray(row["equipment"]),

    injuries:
      row["injuries"] ?? null,

    pain_notes:
      row["pain_notes"] ??
      lifestyle["pain"] ??
      null,

    workout_restriction:
      lifestyle["restriction"] ??
      null,

    exercises_to_avoid:
      asStringArray(
        row["exercises_to_avoid"],
      ),

    activity_level:
      row["job_activity_level"] ??
      lifestyle["activity"] ??
      null,

    workout_intensity:
      lifestyle["workout_intensity"] ??
      null,

    sleep_hours:
      lifestyle["sleep_hours"] ??
      null,

    sleep_quality:
      row["sleep_quality"] ??
      lifestyle["sleep_quality"] ??
      null,

    stress:
      lifestyle["stress"] ??
      null,

    consistency_obstacle:
      lifestyle["obstacle"] ??
      null,

    measurements_cm: {
      waist: row["waist_cm"] ?? null,
      chest: row["chest_cm"] ?? null,
      hips: row["hips_cm"] ?? null,
      arm: row["arm_cm"] ?? null,
      thigh: row["thigh_cm"] ?? null,
      neck: row["neck_cm"] ?? null,
    },

    nutrition_context: {
      eating_style:
        row["diet_preference"] ??
        nutrition["eating_style"] ??
        null,

      nutrition_challenge:
        nutrition["nutrition_challenge"] ??
        null,

      allergies:
        asStringArray(row["allergies"]),

      foods_to_avoid:
        asStringArray(
          row["foods_to_avoid"],
        ),
    },
  };
}

async function generatePlanWithOpenAI(
  apiKey: string,
  foundation: Record<string, unknown>,
  cycleWeeks: number,
  trainingDays: number,
  mode: "generate" | "adjust" = "generate",
  currentPlan: Record<string, unknown> | null = null,
  adjustment: Record<string, unknown> | null = null,
  savedStrategy: Record<string, unknown> | null = null,
) {
  const instructions = savedStrategy
    ? `
You are Stage 2 of the MuscleUp Training Plan Engine.

A trusted Training Strategy has ALREADY been created.
Your job is ONLY to turn that strategy into the concrete training days and exercises.

DO NOT redo user analysis.
DO NOT redefine muscle priorities.
DO NOT rewrite the cycle strategy.
DO NOT contradict the supplied strategy.

Use exactly the supplied day strategies and preserve their day_number, title, focus, and session_strategy.

PROGRAM DESIGN:
- Generate exactly ${trainingDays} training days.
- Keep each session within the supplied session-duration constraint.
- Respect equipment, location, injuries, restrictions, and exercises to avoid.
- Highest-priority demanding work normally goes earlier while the user is fresh.
- Prefer major compound movements before accessory/isolation work unless the supplied strategy justifies otherwise.
- Avoid unnecessary duplicate movement patterns.
- Use exercise order deliberately to manage fatigue.
- Preserve exercise stability for the full ${cycleWeeks}-week cycle.
- reps must be a short human-readable string such as "6-8", "8-10", "10-12", or "30 sec".
- suggested_weight must be a number or null.
- weight_unit must be "lb" or "kg".
- video_url must be null.

MUSCLE DATA:
For every exercise, return primary_muscles and secondary_muscles.
Use ONLY these canonical IDs:
chest, front_delts, side_delts, rear_delts, biceps, triceps, forearms, lats, upper_back, traps, lower_back, core, obliques, glutes, quads, hamstrings, adductors, hip_flexors, calves.
Do not duplicate the same muscle in both arrays.

REASONS:
- selection_reason: one very short sentence, preferably 8-16 words.
- order_reason: one very short sentence, preferably 8-16 words.
- intended_adaptation: 1-4 words such as hypertrophy, strength, endurance, technique, stability, or accessory volume.
- exercise_effect: one short professional sentence describing ONLY the physical training effect of the exercise on the body/muscle.
- exercise_effect must NOT include technique, execution cues, tips, safety instructions, or "why this exercise" language.
- Write exercise_effect like a coach describing what adaptation the user is building, e.g. upper-chest thickness, lat width, delt width, hamstring/glute strength and size.
- Do not repeat the same explanation across fields.
- Keep titles and focus labels concise.

SAFETY:
Fitness programming only. Do not diagnose injuries or prescribe rehabilitation.
Choose conservatively when data is insufficient.

Return only the structured training days.
`
    : `
You are the Training Plan Generator inside MuscleUp.

Create ONE personalized training cycle using ONLY the trusted user data supplied.

MODE:
- generate: create the user's initial training cycle.
- adjust: revise the CURRENT training cycle only because the user explicitly requested a change.

ADJUSTMENT RULES:
- In adjust mode, the user's stated reason is mandatory and is the source of truth for why a change is being requested.
- Never invent a different reason for the adjustment.
- Preserve every unaffected day and exercise as closely as possible.
- Make the smallest sensible change that resolves the user's stated issue.
- If a specific day/exercise is supplied, change only that target unless a small supporting change is necessary for safety or session structure.
- If the reason is too_difficult, first prefer reducing suggested load, sets, reps, or choosing a simpler equivalent variation.
- If the reason is too_easy, use conservative progression rather than redesigning the program.
- If the reason is dislike_exercise, replace the selected exercise with an equivalent that serves a similar training purpose.
- If the reason is missing_equipment, replace only exercises that require unavailable equipment with compatible alternatives.
- If the reason is time_changed, preserve the program's main priorities while fitting sessions into the new available duration.
- If the reason is physical_limitation, avoid movements that conflict with the user's described limitation. Do not diagnose or prescribe rehabilitation.
- Keep the same number of training days unless the user's time constraint truly requires otherwise.
- Do not restart the user's training philosophy from scratch.

OUTPUT EFFICIENCY:
- Return the complete updated plan because the app replaces the saved plan with this response.
- Keep unchanged content concise and as close as possible to the current plan.
- Do not add commentary, markdown, headings, notes, or explanations outside the required JSON fields.
- Keep selection_reason and order_reason to one short sentence each.
- Keep exercise_effect to one short professional sentence.
- Keep session_strategy concise.
- Do not repeat the same idea across multiple fields.

CORE PRODUCT RULES:
- Keep the program structurally stable for the full ${cycleWeeks}-week cycle.
- Generate exactly ${trainingDays} training days.
- Respect goal, level, duration, equipment, location, injuries, restrictions, and exercises to avoid.
- Never invent equipment access.
- If pain/restriction data exists, select conservatively and avoid conflicting movements.

PROGRAMMING LOGIC:
- Highest-priority demanding work normally goes earlier while the user is fresh.
- Prefer major compounds before accessories/isolation unless the strategy clearly justifies another order.
- Avoid unnecessary duplicate movement patterns.
- Use exercise order deliberately to manage fatigue.

MUSCLE DATA:
Use ONLY these canonical IDs:
chest, front_delts, side_delts, rear_delts, biceps, triceps, forearms, lats, upper_back, traps, lower_back, core, obliques, glutes, quads, hamstrings, adductors, hip_flexors, calves.

Return only the structured plan.
`;

  const exerciseProperties = {
    exercise_name: {
      type: "string",
      minLength: 1,
      maxLength: 120,
    },
    sets: {
      type: "integer",
      minimum: 1,
      maximum: 8,
    },
    reps: {
      type: "string",
      minLength: 1,
      maxLength: 40,
    },
    suggested_weight: {
      anyOf: [
        { type: "number", minimum: 0, maximum: 1500 },
        { type: "null" },
      ],
    },
    weight_unit: {
      type: "string",
      enum: ["lb", "kg"],
    },
    rest_seconds: {
      anyOf: [
        { type: "integer", minimum: 30, maximum: 600 },
        { type: "null" },
      ],
    },
    video_url: {
      type: "null",
    },
    primary_muscles: {
      type: "array",
      minItems: 1,
      maxItems: 5,
      items: {
        type: "string",
        enum: CANONICAL_MUSCLES,
      },
    },
    secondary_muscles: {
      type: "array",
      minItems: 0,
      maxItems: 8,
      items: {
        type: "string",
        enum: CANONICAL_MUSCLES,
      },
    },
    selection_reason: {
      type: "string",
      minLength: 1,
      maxLength: 160,
    },
    order_reason: {
      type: "string",
      minLength: 1,
      maxLength: 160,
    },
    intended_adaptation: {
      type: "string",
      minLength: 1,
      maxLength: 80,
    },
    exercise_effect: {
      type: "string",
      minLength: 1,
      maxLength: 220,
    },
  };

  const dayItemSchema = {
    type: "object",
    additionalProperties: false,
    properties: {
      day_number: {
        type: "integer",
        minimum: 1,
        maximum: 7,
      },
      title: {
        type: "string",
        minLength: 1,
        maxLength: 100,
      },
      focus: {
        type: "string",
        minLength: 1,
        maxLength: 160,
      },
      session_strategy: {
        type: "string",
        minLength: 1,
        maxLength: 280,
      },
      exercises: {
        type: "array",
        minItems: 3,
        maxItems: 10,
        items: {
          type: "object",
          additionalProperties: false,
          properties: exerciseProperties,
          required: [
            "exercise_name",
            "sets",
            "reps",
            "suggested_weight",
            "weight_unit",
            "rest_seconds",
            "video_url",
            "primary_muscles",
            "secondary_muscles",
            "selection_reason",
            "order_reason",
            "intended_adaptation",
            "exercise_effect",
          ],
        },
      },
    },
    required: [
      "day_number",
      "title",
      "focus",
      "session_strategy",
      "exercises",
    ],
  };

  const schema = savedStrategy
    ? {
        type: "object",
        additionalProperties: false,
        properties: {
          days: {
            type: "array",
            minItems: trainingDays,
            maxItems: trainingDays,
            items: dayItemSchema,
          },
        },
        required: ["days"],
      }
    : {
        type: "object",
        additionalProperties: false,
        properties: {
          cycle_summary: {
            type: "string",
            minLength: 1,
            maxLength: 260,
          },
          cycle_strategy: {
            type: "string",
            minLength: 1,
            maxLength: 360,
          },
          muscle_priorities: {
            type: "array",
            minItems: 1,
            maxItems: 8,
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                muscle_group: {
                  type: "string",
                  minLength: 1,
                  maxLength: 80,
                },
                priority: {
                  type: "string",
                  enum: ["high", "medium", "maintenance"],
                },
                reason: {
                  type: "string",
                  minLength: 1,
                  maxLength: 180,
                },
              },
              required: ["muscle_group", "priority", "reason"],
            },
          },
          days: {
            type: "array",
            minItems: trainingDays,
            maxItems: trainingDays,
            items: dayItemSchema,
          },
        },
        required: [
          "cycle_summary",
          "cycle_strategy",
          "muscle_priorities",
          "days",
        ],
      };

  const response = await fetch(
    "https://api.openai.com/v1/responses",
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-5-mini",
        reasoning: { effort: "minimal" },
        instructions,
        input: JSON.stringify({
          mode,
          trusted_foundation: foundation,
          cycle_weeks: cycleWeeks,
          training_days: trainingDays,
          current_training_plan: currentPlan,
          adjustment_request: adjustment,
          saved_training_strategy: savedStrategy,
        }),
        max_output_tokens:
          mode === "adjust"
            ? 10000
            : savedStrategy
            ? 7500
            : 7000,
        text: {
          format: {
            type: "json_schema",
            name: "training_plan",
            strict: true,
            schema,
          },
        },
      }),
    },
  );

  const data = await response.json();

  if (!response.ok) {
    console.error(
      "OpenAI Training Plan error:",
      response.status,
      JSON.stringify(data),
    );

    throw new Error(
      "Training plan generation failed.",
    );
  }

  if (data?.status === "incomplete") {
    console.error(
      "OpenAI Training Plan incomplete:",
      JSON.stringify({
        mode,
        incomplete_details: data?.incomplete_details,
        usage: data?.usage,
        output_text_length:
          typeof data?.output_text === "string"
            ? data.output_text.length
            : null,
      }),
    );

    throw new Error(
      `Training plan response was incomplete: ${
        data?.incomplete_details?.reason ?? "unknown_reason"
      }.`,
    );
  }

  const raw = extractOutputText(data);

  if (!raw) {
    console.error(
      "Training Plan returned no output text:",
      JSON.stringify(data),
    );

    throw new Error(
      "Training plan response was empty.",
    );
  }

  try {
    return JSON.parse(raw);
  } catch (error) {
    console.error(
      "Could not parse Training Plan JSON:",
      raw,
      error,
    );

    throw new Error(
      "Training plan response was invalid.",
    );
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(
      "ok",
      { headers: corsHeaders },
    );
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { error: "Method not allowed." },
      405,
    );
  }

  try {
    const supabaseUrl =
      Deno.env.get("SUPABASE_URL") ?? "";

    const anonKey =
      Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const serviceRoleKey =
      Deno.env.get(
        "SUPABASE_SERVICE_ROLE_KEY",
      ) ?? "";

    const openAiKey =
      Deno.env.get("OPENAI_API_KEY") ?? "";

    if (
      !supabaseUrl ||
      !anonKey ||
      !serviceRoleKey
    ) {
      return jsonResponse(
        {
          error:
            "Supabase environment is not configured.",
        },
        500,
      );
    }

    if (!openAiKey) {
      return jsonResponse(
        {
          error:
            "OPENAI_API_KEY is not configured.",
        },
        500,
      );
    }

    const authorization =
      req.headers.get("Authorization") ?? "";

    if (!authorization.startsWith("Bearer ")) {
      return jsonResponse(
        { error: "Unauthorized." },
        401,
      );
    }

    const userClient = createClient(
      supabaseUrl,
      anonKey,
      {
        global: {
          headers: {
            Authorization: authorization,
          },
        },
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      },
    );

    const {
      data: userData,
      error: userError,
    } = await userClient.auth.getUser();

    if (
      userError ||
      !userData?.user?.id
    ) {
      return jsonResponse(
        { error: "Unauthorized." },
        401,
      );
    }

    const userId =
      userData.user.id;

    const admin = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
          detectSessionInUrl: false,
        },
      },
    );

    let requestBody: Record<string, unknown> = {};

    try {
      const parsed = await req.json();
      requestBody = asRecord(parsed);
    } catch (_) {
      requestBody = {};
    }

    const requestedMode =
      String(requestBody["mode"] ?? "generate").trim().toLowerCase();

    const mode: "generate" | "adjust" =
      requestedMode === "adjust" ? "adjust" : "generate";

    const useSavedStrategy =
      mode === "generate" &&
      requestBody["use_saved_strategy"] === true;

    const adjustmentRequest =
      mode === "adjust"
        ? {
            reason_code:
              String(requestBody["reason_code"] ?? "").trim(),
            reason_label:
              String(requestBody["reason_label"] ?? "").trim(),
            day_number:
              requestBody["day_number"] ?? null,
            exercise_name:
              String(requestBody["exercise_name"] ?? "").trim() || null,
            user_note:
              String(requestBody["user_note"] ?? "").trim() || null,
            new_session_minutes:
              requestBody["new_session_minutes"] ?? null,
          }
        : null;

    if (
      mode === "adjust" &&
      !String(adjustmentRequest?.reason_code ?? "").trim()
    ) {
      return jsonResponse(
        {
          error:
            "A user-provided adjustment reason is required.",
        },
        400,
      );
    }

    // Check current active cycle.
    const {
      data: existingPlan,
      error: existingPlanError,
    } = await admin
      .from("training_plans")
      .select(
        "id, user_id, goal, experience_level, cycle_start, cycle_end, cycle_weeks, status, cycle_summary, strategy_summary, muscle_priorities, "
        + "training_days("
        + "id, day_number, title, focus, strategy_reason, "
        + "training_exercises("
        + "id, exercise_name, sets, reps, suggested_weight, weight_unit, rest_seconds, exercise_order, video_url, primary_muscles, secondary_muscles, selection_reason, order_reason, intended_adaptation, exercise_effect"
        + ")"
        + ")",
      )
      .eq("user_id", userId)
      .eq("status", "active")
      .order(
        "created_at",
        { ascending: false },
      )
      .limit(1)
      .maybeSingle();

    if (existingPlanError) {
      console.error(
        "Existing Training Plan lookup error:",
        existingPlanError.message,
      );

      return jsonResponse(
        {
          error:
            "Could not check current Training Plan.",
        },
        500,
      );
    }

    if (mode === "generate" && existingPlan) {
      return jsonResponse({
        created: false,
        source: "existing",
        planId: existingPlan.id,
        cycleStart:
          existingPlan.cycle_start,
        cycleEnd:
          existingPlan.cycle_end,
        cycleWeeks:
          existingPlan.cycle_weeks,
      });
    }

    if (mode === "adjust" && !existingPlan) {
      return jsonResponse(
        {
          error:
            "No active Training Plan exists to adjust.",
        },
        400,
      );
    }

    const {
      data: foundationRow,
      error: foundationError,
    } = await admin
      .from("user_foundations")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();

    if (
      foundationError ||
      !foundationRow
    ) {
      console.error(
        "Foundation lookup error:",
        foundationError?.message,
      );

      return jsonResponse(
        {
          error:
            "Complete My Foundation before generating a Training Plan.",
        },
        400,
      );
    }

    if (
      foundationRow["is_completed"] !== true
    ) {
      return jsonResponse(
        {
          error:
            "Complete My Foundation before generating a Training Plan.",
        },
        400,
      );
    }

    const trustedFoundation =
      buildTrustedFoundation(
        foundationRow,
      );

    const experience =
      normalizeLevel(
        trustedFoundation.training_level,
      );

    const trainingDays =
      mode === "adjust" && existingPlan
        ? Array.isArray(existingPlan.training_days)
          ? existingPlan.training_days.length
          : clampTrainingDays(
              trustedFoundation.training_days_per_week,
            )
        : clampTrainingDays(
            trustedFoundation.training_days_per_week,
          );

    const cycleWeeks =
      mode === "adjust" && existingPlan?.cycle_weeks
        ? Number(existingPlan.cycle_weeks)
        : 4;

    const adjustedFoundation =
      mode === "adjust" &&
      adjustmentRequest?.new_session_minutes != null
        ? {
            ...trustedFoundation,
            session_duration_minutes:
              Number(adjustmentRequest.new_session_minutes),
          }
        : trustedFoundation;

    let savedStrategy: Record<string, unknown> | null = null;

    if (useSavedStrategy) {
      const {
        data: strategyDraft,
        error: strategyDraftError,
      } = await admin
        .from("training_strategy_drafts")
        .select("strategy, training_days, cycle_weeks, status")
        .eq("user_id", userId)
        .eq("status", "ready")
        .maybeSingle();

      if (strategyDraftError || !strategyDraft?.strategy) {
        return jsonResponse(
          {
            error:
              "No ready Training Strategy exists. Generate strategy first.",
          },
          400,
        );
      }

      savedStrategy = asRecord(strategyDraft.strategy);
    }

    const currentPlanForAi =
      mode === "adjust" && existingPlan
        ? {
            id: existingPlan.id,
            goal: existingPlan.goal,
            experience_level:
              existingPlan.experience_level,
            cycle_start:
              existingPlan.cycle_start,
            cycle_end:
              existingPlan.cycle_end,
            cycle_weeks:
              existingPlan.cycle_weeks,
            cycle_summary:
              existingPlan.cycle_summary ?? null,
            cycle_strategy:
              existingPlan.strategy_summary ?? null,
            muscle_priorities:
              existingPlan.muscle_priorities ?? [],
            days:
              Array.isArray(existingPlan.training_days)
                ? [...existingPlan.training_days]
                    .sort(
                      (a: any, b: any) =>
                        Number(a?.day_number ?? 0) -
                        Number(b?.day_number ?? 0),
                    )
                    .map((day: any) => ({
                      day_number: day.day_number,
                      title: day.title,
                      focus: day.focus,
                      session_strategy:
                        day.strategy_reason ?? null,
                      exercises:
                        Array.isArray(day.training_exercises)
                          ? [...day.training_exercises]
                              .sort(
                                (a: any, b: any) =>
                                  Number(a?.exercise_order ?? 0) -
                                  Number(b?.exercise_order ?? 0),
                              )
                              .map((exercise: any) => ({
                                exercise_name:
                                  exercise.exercise_name,
                                sets:
                                  exercise.sets,
                                reps:
                                  exercise.reps,
                                suggested_weight:
                                  exercise.suggested_weight,
                                weight_unit:
                                  exercise.weight_unit,
                                rest_seconds:
                                  exercise.rest_seconds,
                                video_url:
                                  exercise.video_url,
                                primary_muscles:
                                  asStringArray(exercise.primary_muscles),
                                secondary_muscles:
                                  asStringArray(exercise.secondary_muscles),
                                selection_reason:
                                  exercise.selection_reason ?? null,
                                order_reason:
                                  exercise.order_reason ?? null,
                                intended_adaptation:
                                  exercise.intended_adaptation ?? null,
                                exercise_effect:
                                  exercise.exercise_effect ?? null,
                              }))
                          : [],
                    }))
                : [],
          }
        : null;

    const generated =
      await generatePlanWithOpenAI(
        openAiKey,
        adjustedFoundation,
        cycleWeeks,
        trainingDays,
        mode,
        currentPlanForAi,
        adjustmentRequest,
        savedStrategy,
      );

    if (useSavedStrategy && savedStrategy) {
      generated.cycle_summary =
        String(savedStrategy["cycle_summary"] ?? "").trim();
      generated.cycle_strategy =
        String(savedStrategy["cycle_strategy"] ?? "").trim();
      generated.muscle_priorities =
        Array.isArray(savedStrategy["muscle_priorities"])
          ? savedStrategy["muscle_priorities"]
          : [];

      const dayStrategies =
        Array.isArray(savedStrategy["day_strategies"])
          ? savedStrategy["day_strategies"]
          : [];

      generated.days = Array.isArray(generated.days)
        ? generated.days.map((day: any, index: number) => {
            const strategyDay =
              dayStrategies.find(
                (item: any) =>
                  Number(item?.day_number) ===
                  Number(day?.day_number ?? index + 1),
              ) ?? dayStrategies[index] ?? {};

            return {
              ...day,
              day_number:
                Number(strategyDay?.day_number ?? day?.day_number ?? index + 1),
              title:
                String(strategyDay?.title ?? day?.title ?? `Day ${index + 1}`),
              focus:
                String(strategyDay?.focus ?? day?.focus ?? ""),
              session_strategy:
                String(
                  strategyDay?.session_strategy ??
                    day?.session_strategy ??
                    "",
                ),
            };
          })
        : [];
    }

    if (
      !generated ||
      !Array.isArray(generated.days) ||
      generated.days.length !==
        trainingDays
    ) {
      throw new Error(
        "Generated plan structure is invalid.",
      );
    }

    const cycleStart =
      mode === "adjust" && existingPlan?.cycle_start
        ? String(existingPlan.cycle_start)
        : new Date()
            .toISOString()
            .slice(0, 10);

    const cycleEnd =
      mode === "adjust" && existingPlan?.cycle_end
        ? String(existingPlan.cycle_end)
        : addDays(
            cycleStart,
            cycleWeeks * 7 - 1,
          );

    let planId: string | null = null;

    try {
      const {
        data: insertedPlan,
        error: planInsertError,
      } = await admin
        .from("training_plans")
        .insert({
          user_id: userId,
          goal:
            foundationRow["primary_goal"] ??
            null,
          experience_level: experience,
          cycle_start: cycleStart,
          cycle_end: cycleEnd,
          cycle_weeks: cycleWeeks,
          status:
            mode === "adjust"
              ? "archived"
              : "active",
          ai_generated: true,
          cycle_summary:
            String(generated.cycle_summary ?? "").trim() || null,
          strategy_summary:
            String(generated.cycle_strategy ?? "").trim() || null,
          muscle_priorities:
            Array.isArray(generated.muscle_priorities)
              ? generated.muscle_priorities
              : [],
          updated_at:
            new Date().toISOString(),
        })
        .select("id")
        .single();

      if (
        planInsertError ||
        !insertedPlan?.id
      ) {
        throw new Error(
          planInsertError?.message ??
            "Could not save Training Plan.",
        );
      }

      planId =
        insertedPlan.id as string;

      for (
        let index = 0;
        index < generated.days.length;
        index++
      ) {
        const day =
          generated.days[index];

        const dayNumber =
          index + 1;

        const {
          data: insertedDay,
          error: dayInsertError,
        } = await admin
          .from("training_days")
          .insert({
            plan_id: planId,
            day_number: dayNumber,
            title:
              String(
                day.title ?? `Day ${dayNumber}`,
              ).trim(),
            focus:
              String(
                day.focus ?? "",
              ).trim() || null,
            strategy_reason:
              String(
                day.session_strategy ?? "",
              ).trim() || null,
            session_strategy:
              String(
                day.session_strategy ?? "",
              ).trim() || null,
          })
          .select("id")
          .single();

        if (
          dayInsertError ||
          !insertedDay?.id
        ) {
          throw new Error(
            dayInsertError?.message ??
              `Could not save Day ${dayNumber}.`,
          );
        }

        const trainingDayId =
          insertedDay.id as string;

        const exercises =
          Array.isArray(day.exercises)
            ? day.exercises
            : [];

        if (exercises.length === 0) {
          throw new Error(
            `Day ${dayNumber} has no exercises.`,
          );
        }

        const exerciseRows =
          exercises.map(
            (
              exercise: any,
              exerciseIndex: number,
            ) => ({
              training_day_id:
                trainingDayId,
              exercise_name:
                String(
                  exercise.exercise_name ??
                    "",
                ).trim(),
              sets:
                Number(
                  exercise.sets,
                ),
              reps:
                String(
                  exercise.reps ?? "",
                ).trim(),
              suggested_weight:
                exercise.suggested_weight ===
                    null
                  ? null
                  : Number(
                      exercise
                        .suggested_weight,
                    ),
              weight_unit:
                exercise.weight_unit === "kg"
                  ? "kg"
                  : "lb",
              rest_seconds:
                exercise.rest_seconds ===
                    null
                  ? null
                  : Number(
                      exercise.rest_seconds,
                    ),
              exercise_order:
                exerciseIndex + 1,
              video_url: null,
              primary_muscles:
                normalizeCanonicalMuscles(
                  exercise.primary_muscles,
                ),
              secondary_muscles:
                normalizeCanonicalMuscles(
                  exercise.secondary_muscles,
                ),
              selection_reason:
                String(
                  exercise.selection_reason ?? "",
                ).trim() || null,
              order_reason:
                String(
                  exercise.order_reason ?? "",
                ).trim() || null,
              intended_adaptation:
                String(
                  exercise.intended_adaptation ?? "",
                ).trim() || null,
              exercise_effect:
                String(
                  exercise.exercise_effect ?? "",
                ).trim() || null,
            }),
          );

        const {
          error: exerciseInsertError,
        } = await admin
          .from("training_exercises")
          .insert(exerciseRows);

        if (exerciseInsertError) {
          throw new Error(
            exerciseInsertError.message,
          );
        }
      }

      if (
        mode === "adjust" &&
        existingPlan?.id &&
        planId
      ) {
        const oldPlanId =
          String(existingPlan.id);

        const {
          error: archiveOldError,
        } = await admin
          .from("training_plans")
          .update({
            status: "archived",
            updated_at:
              new Date().toISOString(),
          })
          .eq("id", oldPlanId);

        if (archiveOldError) {
          throw new Error(
            `Could not archive previous plan: ${archiveOldError.message}`,
          );
        }

        const {
          error: activateNewError,
        } = await admin
          .from("training_plans")
          .update({
            status: "active",
            updated_at:
              new Date().toISOString(),
          })
          .eq("id", planId);

        if (activateNewError) {
          await admin
            .from("training_plans")
            .update({
              status: "active",
              updated_at:
                new Date().toISOString(),
            })
            .eq("id", oldPlanId);

          throw new Error(
            `Could not activate adjusted plan: ${activateNewError.message}`,
          );
        }
      }

      if (useSavedStrategy) {
        await admin
          .from("training_strategy_drafts")
          .delete()
          .eq("user_id", userId);
      }

      return jsonResponse({
        created: true,
        adjusted:
          mode === "adjust",
        source: "ai",
        planId,
        replacedPlanId:
          mode === "adjust"
            ? existingPlan?.id ?? null
            : null,
        cycleStart,
        cycleEnd,
        cycleWeeks,
        trainingDays,
        cycleSummary:
          generated.cycle_summary ??
          null,
        cycleStrategy:
          generated.cycle_strategy ??
          null,
        musclePriorities:
          generated.muscle_priorities ??
          [],
        adjustment:
          mode === "adjust"
            ? adjustmentRequest
            : null,
      });
    } catch (saveError) {
      // Roll back the plan tree if any child insert fails.
      // training_days and training_exercises cascade from training_plans.
      if (planId) {
        await admin
          .from("training_plans")
          .delete()
          .eq("id", planId);
      }

      throw saveError;
    }
  } catch (error) {
    console.error(
      "generate-training-plan error:",
      error,
    );

    return jsonResponse(
      {
        error:
          error instanceof Error
            ? error.message
            : "Could not generate Training Plan.",
      },
      500,
    );
  }
});
