import {
  buildPrompt,
  canonicalContext,
  HORIZON_MONTHS,
  isUserScopedPrivatePath,
  persistenceMetadata,
  privateOutputPath,
  validationMessage,
} from "./logic.ts";

const assert = (condition: unknown, message: string) => {
  if (!condition) throw new Error(message);
};

const vision = {
  primary_goal: "vision-client-goal",
  desired_feelings: ["capable"],
  future_identity: "I am strong and consistent.",
  current_photo_path: "user-1/current/photo.jpg",
  current_photo_input_mode: "full_body",
  future_self_input_mode: "full_body",
};

Deno.test("canonical Foundation overrides client profile facts", () => {
  const context = canonicalContext(
    {
      inputMode: "full_body",
      currentPhotoPath: vision.current_photo_path,
      primaryGoal: "client override",
      age: 99,
      heightCm: 999,
      futureHorizonMonths: 8,
    },
    vision,
    {
      primary_goal: "build_muscle",
      age: 32,
      height_cm: 170,
      weight_kg: 70,
      target_weight_kg: 74,
      training_level: "beginner",
    },
  );
  assert(context.primaryGoal === "build_muscle", "goal must be canonical");
  assert(context.age === 32, "age must be canonical");
  assert(context.heightCm === 170, "height must be canonical");
  assert(context.futureHorizonMonths === HORIZON_MONTHS, "horizon must be fixed");
});

Deno.test("prompt preserves fullBody mode and eight-month horizon", () => {
  const context = canonicalContext(
    { inputMode: "full_body", currentPhotoPath: vision.current_photo_path },
    vision,
    { primary_goal: "build_muscle" },
  );
  const prompt = buildPrompt(context);
  assert(prompt.includes("8 months"), "prompt must include eight months");
  assert(prompt.includes("FULL BODY MODE"), "prompt must preserve mode");
  assert(prompt.includes("shoulder alignment"), "prompt must preserve anatomy");
});

Deno.test("validation rejection is actionable and user safe", () => {
  const message = validationMessage({
    personCount: 1,
    faceVisible: true,
    fullBodyVisible: false,
    excessivelyCropped: true,
    usablePose: true,
    adequateLighting: true,
    ordinaryNonSexualClothing: true,
    sexualizedPoseOrNudity: false,
  }, "full_body");
  assert(message === "Your full body isn't visible.", "message should be actionable");
});

Deno.test("generation metadata persists mode horizon source and goal", () => {
  const metadata = persistenceMetadata("full_body", vision.current_photo_path, "build_muscle");
  assert(metadata.future_self_generated_input_mode === "full_body", "mode missing");
  assert(metadata.future_self_horizon_months === 8, "horizon missing");
  assert(metadata.future_self_source_reference === vision.current_photo_path, "source missing");
  assert(metadata.future_self_goal_used === "build_muscle", "goal missing");
});

Deno.test("generated storage references remain private and user scoped", () => {
  const path = privateOutputPath("user-1", 123);
  assert(path === "user-1/future/123.png", "unexpected private path");
  assert(isUserScopedPrivatePath("user-1", path), "path must be user scoped");
  assert(!isUserScopedPrivatePath("user-2", path), "other users must not match");
  assert(!path.startsWith("http"), "result must not be public URL");
});
