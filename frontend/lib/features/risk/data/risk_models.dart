class RiskFeaturesModel {
  final int age;
  final int sex;
  final int chestPainType;
  final int restingBp;
  final int cholesterol;
  final int fastingBloodSugar;
  final int restingEcg;
  final int maxHeartRate;
  final int exerciseAngina;
  final double oldpeak;
  final int stSlope;

  RiskFeaturesModel({
    required this.age,
    required this.sex,
    required this.chestPainType,
    required this.restingBp,
    required this.cholesterol,
    required this.fastingBloodSugar,
    required this.restingEcg,
    required this.maxHeartRate,
    required this.exerciseAngina,
    required this.oldpeak,
    required this.stSlope,
  });

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'sex': sex,
      'chest_pain_type': chestPainType,
      'resting_bp': restingBp,
      'cholesterol': cholesterol,
      'fasting_blood_sugar': fastingBloodSugar,
      'resting_ecg': restingEcg,
      'max_heart_rate': maxHeartRate,
      'exercise_angina': exerciseAngina,
      'oldpeak': oldpeak,
      'st_slope': stSlope,
    };
  }
}

class HeartRiskResponseModel {
  final int riskPredicted;
  final double riskProbability;
  final String engine;

  HeartRiskResponseModel({
    required this.riskPredicted,
    required this.riskProbability,
    required this.engine,
  });

  factory HeartRiskResponseModel.fromJson(Map<String, dynamic> json) {
    return HeartRiskResponseModel(
      riskPredicted: json['risk_predicted'] as int,
      riskProbability: (json['risk_probability'] as num).toDouble(),
      engine: json['engine'] as String? ?? '',
    );
  }
}
