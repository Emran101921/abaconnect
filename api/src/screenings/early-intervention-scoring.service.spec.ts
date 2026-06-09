import { EarlyInterventionScoringService } from './early-intervention-scoring.service';

describe('EarlyInterventionScoringService', () => {
  const service = new EarlyInterventionScoringService();

  it('recommends speech therapy for communication delays', () => {
    const result = service.score({
      b_uses_words: 'Never',
      b_understands_others: 'Sometimes',
      b_follows_directions: 'Never',
      b_communication_frustration: 'Often',
      b_gestures: 'Never',
    });

    expect(result.recommendations.some((r) => r.code === 'SPEECH')).toBe(true);
    expect(result.areaFlags.speech).toBe(true);
  });

  it('recommends ABA for behavioral and social concerns', () => {
    const result = service.score({
      b_eye_contact: 'Never',
      c_social_interaction: 'Never',
      c_repetitive_behaviors: 'Often',
      c_tantrums: 'Always',
      c_aggression: 'Often',
      c_routine_changes: 'Often',
      c_elopement: 'Sometimes',
    });

    expect(result.recommendations.some((r) => r.code === 'ABA')).toBe(true);
    expect(result.areaFlags.aba).toBe(true);
  });

  it('recommends OT for fine motor and sensory concerns', () => {
    const result = service.score({
      d_crayon: 'No',
      d_blocks: 'No',
      d_small_objects: 'Emerging',
      d_textures: 'No',
      d_utensils: 'No',
      d_dressing: 'Emerging',
      d_sits_activities: 'No',
    });

    expect(result.recommendations.some((r) => r.code === 'OCCUPATIONAL')).toBe(
      true,
    );
    expect(result.areaFlags.ot).toBe(true);
  });

  it('recommends PT for gross motor delays', () => {
    const result = service.score({
      e_sits: 'No',
      e_crawls: 'No',
      e_walks: 'Emerging',
      e_runs: 'No',
      e_jumps: 'No',
      e_balance: 'No',
      e_falls: 'Yes',
      e_toe_walking: 'Yes',
    });

    expect(result.recommendations.some((r) => r.code === 'PHYSICAL')).toBe(
      true,
    );
    expect(result.areaFlags.pt).toBe(true);
  });

  it('recommends feeding therapy for swallowing and diet concerns', () => {
    const result = service.score({
      f_swallowing: 'Yes',
      f_chewing: 'Sometimes',
      f_gagging: 'Yes',
      f_less_20_foods: 'Yes',
      f_refuses_new: 'Yes',
      a_feeding_swallowing: true,
    });

    expect(result.recommendations.some((r) => r.code === 'FEEDING')).toBe(true);
    expect(result.areaFlags.feeding).toBe(true);
  });

  it('recommends developmental intervention when 2+ areas flagged', () => {
    const result = service.score({
      b_uses_words: 'Never',
      c_social_interaction: 'Never',
      d_crayon: 'No',
      e_walks: 'No',
    });

    expect(result.recommendations.some((r) => r.code === 'DEVELOPMENTAL')).toBe(
      true,
    );
  });

  it('assigns HIGH risk for many concurrent concerns', () => {
    const result = service.score({
      b_uses_words: 'Never',
      b_understands_others: 'Never',
      c_social_interaction: 'Never',
      c_tantrums: 'Always',
      d_crayon: 'No',
      e_walks: 'No',
      f_swallowing: 'Yes',
      a_medical_diagnosis: true,
    });

    expect(result.riskLevel).toBe('HIGH');
    expect(result.score).toBeGreaterThan(0.5);
  });

  it('assigns LOW risk for mostly typical responses', () => {
    const result = service.score({
      b_responds_to_name: 'Always',
      b_uses_words: 'Always',
      c_plays_with_others: 'Often',
      d_crayon: 'Yes',
      e_walks: 'Yes',
      f_picky_eater: 'No',
    });

    expect(result.riskLevel).toBe('LOW');
    expect(result.recommendations).toHaveLength(0);
  });
});
