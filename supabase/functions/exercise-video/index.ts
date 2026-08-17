const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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

function normalizeExerciseKey(
  value: string,
): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

async function resolveMoveKitVideo(
  exerciseName: string,
): Promise<{
  status: "ready" | "coming_soon" | "unavailable";
  provider: "movekit";
  exercise_id?: string;
  video_url?: string;
  message?: string;
}> {
  const apiKey =
    Deno.env.get("MOVEKIT_API_KEY")?.trim() ?? "";

  if (!apiKey) {
    return {
      status: "coming_soon",
      provider: "movekit",
      message:
        "MoveKit API access is not connected yet. "
        + "The app video layer is ready for launch-time integration.",
    };
  }

  // MoveKit's public page currently shows only a planned API sketch.
  // Do not guess the final endpoint or schema.
  // When official docs launch, replace ONLY this function with:
  // search exercise -> get MoveKit exercise id -> request signed video URL.
  return {
    status: "coming_soon",
    provider: "movekit",
    message:
      "MoveKit credentials are configured, but the final public API "
      + "contract has not been enabled in this adapter yet.",
  };
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
    const body =
      await req.json() as Record<string, unknown>;

    const exerciseName =
      String(body["exercise_name"] ?? "").trim();

    if (!exerciseName) {
      return jsonResponse(
        {
          status: "unavailable",
          provider: "movekit",
          message: "exercise_name is required.",
        },
        400,
      );
    }

    const result =
      await resolveMoveKitVideo(exerciseName);

    return jsonResponse({
      ...result,
      exercise_key:
        normalizeExerciseKey(exerciseName),
      requested_exercise:
        exerciseName,
    });
  } catch (error) {
    console.error(
      "exercise-video error:",
      error,
    );

    return jsonResponse(
      {
        status: "unavailable",
        provider: "movekit",
        message:
          error instanceof Error
            ? error.message
            : "Could not resolve exercise video.",
      },
      500,
    );
  }
});
