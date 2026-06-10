import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/risk_api.dart';
import '../data/risk_models.dart';

class RiskState {
  final bool isLoading;
  final double? resultScore;
  final int? resultClass;
  final String? engineUsed;
  final String? errorMessage;

  RiskState({
    this.isLoading = false,
    this.resultScore,
    this.resultClass,
    this.engineUsed,
    this.errorMessage,
  });

  RiskState copyWith({
    bool? isLoading,
    double? resultScore,
    int? resultClass,
    String? engineUsed,
    String? errorMessage,
  }) {
    return RiskState(
      isLoading: isLoading ?? this.isLoading,
      resultScore: resultScore,
      resultClass: resultClass,
      engineUsed: engineUsed ?? this.engineUsed,
      errorMessage: errorMessage,
    );
  }
}

class RiskNotifier extends AutoDisposeNotifier<RiskState> {
  @override
  RiskState build() {
    return RiskState();
  }

  Future<void> evaluateRisk(RiskFeaturesModel features) async {
    state = RiskState(isLoading: true);
    try {
      final riskApi = ref.read(riskApiProvider);
      final response = await riskApi.predictHeartRisk(features);
      state = RiskState(
        isLoading: false,
        resultScore: response.riskProbability * 100,
        resultClass: response.riskPredicted,
        engineUsed: response.engine,
      );
    } catch (e) {
      state = RiskState(
        isLoading: false,
        errorMessage: "Failed to get prediction. Check your connection.",
      );
    }
  }

  void reset() {
    state = RiskState();
  }
}

final riskProvider =
    NotifierProvider.autoDispose<RiskNotifier, RiskState>(RiskNotifier.new);
