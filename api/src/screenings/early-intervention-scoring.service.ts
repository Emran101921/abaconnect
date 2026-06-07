import { Injectable } from '@nestjs/common';

export interface ServiceRecommendation {
  service: string;
  code: string;
  explanation: string;
}

export interface EarlyInterventionScoreResult {
  score: number;
  riskLevel: 'LOW' | 'MODERATE' | 'HIGH';
  recommendations: ServiceRecommendation[];
  areaFlags: Record<string, boolean>;
}

@Injectable()
export class EarlyInterventionScoringService {
  score(responses: Record<string, unknown>): EarlyInterventionScoreResult {
    const areaFlags = {
      medical: this.medicalConcern(responses),
      speech: this.speechConcern(responses),
      aba: this.abaConcern(responses),
      ot: this.otConcern(responses),
      pt: this.ptConcern(responses),
      feeding: this.feedingConcern(responses),
    };

    const recommendations: ServiceRecommendation[] = [];

    if (this.recommendSpeech(responses)) {
      recommendations.push({
        service: 'Speech Therapy',
        code: 'SPEECH',
        explanation:
          'Responses suggest delays in communication, understanding, or expressive language that may benefit from speech-language evaluation.',
      });
    }

    if (this.recommendAba(responses)) {
      recommendations.push({
        service: 'Applied Behavior Analysis (ABA)',
        code: 'ABA',
        explanation:
          'Social, behavioral, or safety concerns were noted that may benefit from ABA assessment and support.',
      });
    }

    if (this.recommendOt(responses)) {
      recommendations.push({
        service: 'Occupational Therapy',
        code: 'OCCUPATIONAL',
        explanation:
          'Fine motor, sensory, or daily living skill concerns were identified that may benefit from occupational therapy.',
      });
    }

    if (this.recommendPt(responses)) {
      recommendations.push({
        service: 'Physical Therapy',
        code: 'PHYSICAL',
        explanation:
          'Gross motor or mobility concerns were noted that may benefit from physical therapy evaluation.',
      });
    }

    if (this.recommendFeeding(responses)) {
      recommendations.push({
        service: 'Feeding Therapy',
        code: 'FEEDING',
        explanation:
          'Feeding, swallowing, or dietary restriction concerns were reported that may benefit from feeding therapy.',
      });
    }

    const developmentalAreas = [
      areaFlags.speech,
      areaFlags.aba,
      areaFlags.ot,
      areaFlags.pt,
      areaFlags.feeding,
    ].filter(Boolean).length;

    if (developmentalAreas >= 2) {
      recommendations.push({
        service: 'Developmental Intervention',
        code: 'DEVELOPMENTAL',
        explanation:
          'Concerns were noted in multiple developmental areas. A comprehensive developmental evaluation is recommended.',
      });
    }

    const concernCount = Object.values(areaFlags).filter(Boolean).length;
    const aggregateScore = this.aggregateScore(responses, concernCount);
    const riskLevel = this.riskLevelFromScore(aggregateScore, concernCount);

    return {
      score: aggregateScore,
      riskLevel,
      recommendations,
      areaFlags,
    };
  }

  private medicalConcern(responses: Record<string, unknown>): boolean {
    return (
      this.isYes(responses.a_premature_birth) ||
      this.isYes(responses.a_pregnancy_complications) ||
      this.isYes(responses.a_medical_diagnosis) ||
      this.isYes(responses.a_hearing_concerns) ||
      this.isYes(responses.a_vision_concerns) ||
      this.isYes(responses.a_feeding_swallowing)
    );
  }

  private recommendSpeech(responses: Record<string, unknown>): boolean {
    return (
      this.freqLow(responses.b_uses_words) ||
      this.freqLow(responses.b_understands_others) ||
      this.freqLow(responses.b_follows_directions) ||
      this.freqHigh(responses.b_communication_frustration) ||
      this.freqLow(responses.b_gestures)
    );
  }

  private speechConcern(responses: Record<string, unknown>): boolean {
    return this.recommendSpeech(responses);
  }

  private recommendAba(responses: Record<string, unknown>): boolean {
    return (
      this.freqLow(responses.b_eye_contact) ||
      this.freqLow(responses.c_social_interaction) ||
      this.freqHigh(responses.c_repetitive_behaviors) ||
      this.freqHigh(responses.c_tantrums) ||
      this.freqHigh(responses.c_aggression) ||
      this.freqHigh(responses.c_routine_changes) ||
      this.freqHigh(responses.c_elopement)
    );
  }

  private abaConcern(responses: Record<string, unknown>): boolean {
    return this.recommendAba(responses);
  }

  private recommendOt(responses: Record<string, unknown>): boolean {
    return (
      this.skillNo(responses.d_crayon) ||
      this.skillNo(responses.d_blocks) ||
      this.skillNo(responses.d_small_objects) ||
      this.skillNo(responses.d_textures) ||
      this.skillNo(responses.d_loud_noises) ||
      this.skillNo(responses.d_utensils) ||
      this.skillNo(responses.d_dressing) ||
      this.skillNo(responses.d_sits_activities)
    );
  }

  private otConcern(responses: Record<string, unknown>): boolean {
    return this.recommendOt(responses);
  }

  private recommendPt(responses: Record<string, unknown>): boolean {
    return (
      this.skillNo(responses.e_sits) ||
      this.skillNo(responses.e_crawls) ||
      this.skillNo(responses.e_walks) ||
      this.skillNo(responses.e_runs) ||
      this.skillNo(responses.e_jumps) ||
      this.skillNo(responses.e_balance) ||
      this.skillEmergingOrNo(responses.e_falls) ||
      this.skillEmergingOrNo(responses.e_toe_walking)
    );
  }

  private ptConcern(responses: Record<string, unknown>): boolean {
    return this.recommendPt(responses);
  }

  private recommendFeeding(responses: Record<string, unknown>): boolean {
    return (
      this.feedConcern(responses.f_swallowing) ||
      this.feedConcern(responses.f_chewing) ||
      this.feedConcern(responses.f_gagging) ||
      this.feedConcern(responses.f_less_20_foods) ||
      this.feedConcern(responses.f_refuses_new) ||
      this.isYes(responses.a_feeding_swallowing)
    );
  }

  private feedingConcern(responses: Record<string, unknown>): boolean {
    return this.recommendFeeding(responses);
  }

  private aggregateScore(
    responses: Record<string, unknown>,
    areaConcernCount: number,
  ): number {
    let medicalYes = 0;
    let medicalTotal = 0;
    for (const [key, value] of Object.entries(responses)) {
      if (!key.startsWith('a_')) continue;
      medicalTotal += 1;
      if (this.isYes(value)) medicalYes += 1;
    }
    const medicalBoost =
      medicalTotal > 0 ? (medicalYes / medicalTotal) * 0.25 : 0;
    const areaBoost = Math.min(areaConcernCount / 6, 1) * 0.75;
    return Number(Math.min(1, medicalBoost + areaBoost).toFixed(2));
  }

  private riskLevelFromScore(
    score: number,
    areaConcernCount: number,
  ): 'LOW' | 'MODERATE' | 'HIGH' {
    if (score >= 0.65 || areaConcernCount >= 4) return 'HIGH';
    if (score >= 0.35 || areaConcernCount >= 2) return 'MODERATE';
    return 'LOW';
  }

  private isYes(value: unknown): boolean {
    return value === true || value === 'yes' || value === 'Yes';
  }

  private freqLow(value: unknown): boolean {
    return value === 'Never' || value === 'Sometimes';
  }

  private freqHigh(value: unknown): boolean {
    return value === 'Often' || value === 'Always';
  }

  private skillNo(value: unknown): boolean {
    return value === 'No';
  }

  private skillEmergingOrNo(value: unknown): boolean {
    return value === 'No' || value === 'Emerging';
  }

  private feedConcern(value: unknown): boolean {
    return value === 'Yes' || value === 'Sometimes';
  }
}
