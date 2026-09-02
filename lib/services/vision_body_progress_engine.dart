import 'package:future_project/models/body_progress.dart';
import 'package:future_project/models/future_vision.dart';

class VisionBodyProgressEngine {
  const VisionBodyProgressEngine();

  VisionEvidence? evidenceFor(List<BodyProgressCheck> history) {
    if (history.isEmpty) return null;
    final latest = history.reduce(
      (current, item) =>
          item.checkedAt.isAfter(current.checkedAt) ? item : current,
    );
    final checkCount = history.length;
    return VisionEvidence(
      type: VisionEvidenceType.bodyProgress,
      label: checkCount == 1
          ? 'You measured change from your starting point'
          : 'You kept measuring your body progress',
      detail: checkCount == 1
          ? 'Your first check now updates your Vision progress and milestones.'
          : '$checkCount Body Progress checks are showing how your body is changing over time.',
      priority: checkCount == 1 ? 85 : 95,
      occurredAt: latest.checkedAt,
    );
  }

  VisionTodayAction? dueActionFor(BodyProgressCycle? cycle) {
    if (cycle?.status != BodyProgressCycleStatus.due) return null;
    return const VisionTodayAction(
      action: 'Complete your Body Progress check',
      source: 'Body Progress • Due now',
      explanation:
          'Your measurement window is open. A check today will update your Vision progress and milestones.',
      ctaLabel: 'Start Body Progress Check',
      destination: VisionActionDestination.bodyProgress,
    );
  }
}
