import 'package:flutter/material.dart';
import 'package:future_project/models/smart_supplement.dart';

String supplementStatusLabel(
  SmartSupplementRecommendation item, {
  bool detailed = false,
}) => switch (item.status) {
  SupplementGuidanceStatus.recommended =>
    detailed ? 'RECOMMENDED FOR YOU' : 'RECOMMENDED',
  SupplementGuidanceStatus.usefulWhenNeeded => 'USEFUL WHEN NEEDED',
  SupplementGuidanceStatus.worthConsidering => 'WORTH CONSIDERING',
  SupplementGuidanceStatus.generalConsideration => 'CONSIDER',
  SupplementGuidanceStatus.contextDependent =>
    item.id == 'caffeine' ? 'OPTIONAL PERFORMANCE AID' : 'CONTEXT DEPENDENT',
};

IconData supplementIcon(String id) => switch (id) {
  'creatine_monohydrate' => Icons.fitness_center_outlined,
  'whey_protein' || 'plant_protein' => Icons.local_drink_outlined,
  'omega_3' => Icons.water_drop_outlined,
  'electrolytes' => Icons.bolt_outlined,
  'caffeine' => Icons.coffee_outlined,
  'vitamin_d' => Icons.wb_sunny_outlined,
  'magnesium' => Icons.bedtime_outlined,
  _ => Icons.health_and_safety_outlined,
};

String supplementCompactSummary(SmartSupplementRecommendation item) {
  if (item.id == 'whey_protein' || item.id == 'plant_protein') {
    return 'Helps support your protein target';
  }
  return item.benefits.take(3).join(' • ');
}

String? supplementTimingGuidance(SmartSupplementRecommendation item) =>
    switch (item.id) {
      'creatine_monohydrate' =>
        'Daily. Consistency matters more than exact timing.',
      'whey_protein' || 'plant_protein' =>
        'Use when convenient on days your usual meals fall short.',
      'electrolytes' =>
        'Use around long, demanding, hot, or high-sweat sessions.',
      'caffeine' =>
        'Use before selected performance sessions while protecting sleep.',
      _ => null,
    };

String? supplementAmountGuidance(SmartSupplementRecommendation item) {
  if (item.guidance.generalUse != null) return item.guidance.generalUse;
  if (item.id == 'vitamin_d' || item.id == 'magnesium') {
    return 'Individual need and dosage require appropriate supporting context or professional guidance.';
  }
  return null;
}
