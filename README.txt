MuscleUp anatomy integration

1) Copy:
   assets/exercises/anatomy/
   into your project at the same path.

2) Copy:
   lib/services/exercise_anatomy_service.dart

3) Replace:
   lib/screens/training_plan_screen.dart

4) In pubspec.yaml, under flutter:, make sure you have:
   assets:
     - assets/exercises/anatomy/

5) Run:
   flutter pub get
   flutter analyze
   flutter run -d windows

Included anatomy assets:
- Barbell Bench Press
- Barbell Bent-Over Row
- Medicine Ball Chest Pass (Explosive)
- Weighted Pull-Up
- Incline Dumbbell Press
- Face Pulls

Behavior:
- Training Plan cards show an anatomy thumbnail when an asset exists.
- Exercise Detail > Muscles shows the full Front/Back anatomy image.
- Primary/secondary muscle text still comes from Supabase.
- Exercises without an anatomy asset automatically fall back to the current body-map painter.
