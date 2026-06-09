export type EIQuestionType =
  | 'yes_no'
  | 'frequency'
  | 'skill_level'
  | 'feeding_level'
  | 'text'
  | 'text_list';

export interface EIQuestion {
  id: string;
  text: string;
  type: EIQuestionType;
  options?: string[];
}

export interface EISection {
  id: string;
  title: string;
  description?: string;
  questions: EIQuestion[];
}

export const EARLY_INTERVENTION_TEMPLATE_NAME =
  'Early Intervention Parent Screening';

export const EARLY_INTERVENTION_SECTIONS: EISection[] = [
  {
    id: 'A',
    title: 'Medical History',
    description: 'Please answer yes or no for each item.',
    questions: [
      {
        id: 'a_premature_birth',
        text: 'Was your child born prematurely (before 37 weeks)?',
        type: 'yes_no',
      },
      {
        id: 'a_pregnancy_complications',
        text: 'Were there pregnancy or birth complications?',
        type: 'yes_no',
      },
      {
        id: 'a_medical_diagnosis',
        text: 'Does your child have a medical diagnosis?',
        type: 'yes_no',
      },
      {
        id: 'a_hearing_concerns',
        text: "Do you have concerns about your child's hearing?",
        type: 'yes_no',
      },
      {
        id: 'a_vision_concerns',
        text: "Do you have concerns about your child's vision?",
        type: 'yes_no',
      },
      {
        id: 'a_feeding_swallowing',
        text: 'Do you have feeding or swallowing concerns?',
        type: 'yes_no',
      },
    ],
  },
  {
    id: 'B',
    title: 'Speech & Communication',
    description: 'How often does your child demonstrate the following?',
    questions: [
      {
        id: 'b_responds_to_name',
        text: 'Responds when called by name',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'b_eye_contact',
        text: 'Makes eye contact during interactions',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'b_gestures',
        text: 'Uses gestures (pointing, waving, nodding)',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'b_follows_directions',
        text: 'Follows simple directions',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'b_uses_words',
        text: 'Uses words to communicate needs',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'b_combines_phrases',
        text: 'Combines two or more words into phrases',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'b_understands_others',
        text: 'Understands what others say',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'b_communication_frustration',
        text: 'Shows frustration when trying to communicate',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
    ],
  },
  {
    id: 'C',
    title: 'Social & Behavior / ABA',
    description: 'How often does your child demonstrate the following?',
    questions: [
      {
        id: 'c_plays_with_others',
        text: 'Plays with other children',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'c_shares_toys',
        text: 'Shares toys or takes turns',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'c_pretend_play',
        text: 'Engages in pretend or imaginative play',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'c_social_interaction',
        text: 'Initiates social interaction with peers or adults',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'c_repetitive_behaviors',
        text: 'Engages in repetitive behaviors (hand flapping, lining up toys)',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'c_routine_changes',
        text: 'Becomes upset with routine changes or transitions',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'c_tantrums',
        text: 'Has frequent tantrums or meltdowns',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'c_aggression',
        text: 'Shows aggression or self-injurious behavior',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
      {
        id: 'c_elopement',
        text: 'Wanders or elopes from safe areas',
        type: 'frequency',
        options: ['Never', 'Sometimes', 'Often', 'Always'],
      },
    ],
  },
  {
    id: 'D',
    title: 'Occupational Therapy',
    description: 'Can your child do the following?',
    questions: [
      {
        id: 'd_utensils',
        text: 'Use utensils to eat',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'd_crayon',
        text: 'Hold and use a crayon or pencil',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'd_blocks',
        text: 'Stack blocks or manipulate small toys',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'd_small_objects',
        text: 'Pick up small objects with fingers',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'd_dressing',
        text: 'Participate in dressing (buttons, zippers, shoes)',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'd_textures',
        text: 'Tolerate different textures (food, clothing, touch)',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'd_loud_noises',
        text: 'Tolerate loud noises or busy environments',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'd_sits_activities',
        text: 'Sit and participate in table activities',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
    ],
  },
  {
    id: 'E',
    title: 'Physical Therapy',
    description: 'Can your child do the following?',
    questions: [
      {
        id: 'e_sits',
        text: 'Sit independently',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'e_crawls',
        text: 'Crawl or move on hands and knees',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'e_walks',
        text: 'Walk independently',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'e_runs',
        text: 'Run',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'e_jumps',
        text: 'Jump with both feet',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'e_stairs',
        text: 'Climb stairs with support or independently',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'e_balance',
        text: 'Maintain balance during play',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'e_falls',
        text: 'Falls frequently compared to peers',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
      {
        id: 'e_toe_walking',
        text: 'Walks on toes frequently',
        type: 'skill_level',
        options: ['No', 'Emerging', 'Yes'],
      },
    ],
  },
  {
    id: 'F',
    title: 'Feeding',
    description: 'Does your child experience the following?',
    questions: [
      {
        id: 'f_picky_eater',
        text: 'Is a picky eater with limited food variety',
        type: 'feeding_level',
        options: ['No', 'Sometimes', 'Yes'],
      },
      {
        id: 'f_less_20_foods',
        text: 'Eats fewer than 20 different foods',
        type: 'feeding_level',
        options: ['No', 'Sometimes', 'Yes'],
      },
      {
        id: 'f_chewing',
        text: 'Has difficulty chewing food',
        type: 'feeding_level',
        options: ['No', 'Sometimes', 'Yes'],
      },
      {
        id: 'f_swallowing',
        text: 'Has difficulty swallowing',
        type: 'feeding_level',
        options: ['No', 'Sometimes', 'Yes'],
      },
      {
        id: 'f_gagging',
        text: 'Gags or chokes during meals',
        type: 'feeding_level',
        options: ['No', 'Sometimes', 'Yes'],
      },
      {
        id: 'f_refuses_new',
        text: 'Refuses to try new foods',
        type: 'feeding_level',
        options: ['No', 'Sometimes', 'Yes'],
      },
      {
        id: 'f_cup_drinking',
        text: 'Drinks from an open cup or straw',
        type: 'feeding_level',
        options: ['No', 'Sometimes', 'Yes'],
      },
    ],
  },
  {
    id: 'G',
    title: 'Parent Concerns',
    description: 'Share your top concerns and goals.',
    questions: [
      {
        id: 'g_top_concerns',
        text: "What are your top 3 concerns about your child's development?",
        type: 'text',
      },
      {
        id: 'g_goals',
        text: 'What goals do you have for your child?',
        type: 'text',
      },
      {
        id: 'g_services_needed',
        text: 'Which services do you think your child may need?',
        type: 'text',
      },
    ],
  },
];

export function buildEarlyInterventionQuestionsJson() {
  return {
    templateKey: 'EARLY_INTERVENTION',
    sections: EARLY_INTERVENTION_SECTIONS,
  };
}

export interface SanitizedSectionAnswer {
  sectionId: string;
  sectionTitle: string;
  answers: Array<{
    questionId: string;
    question: string;
    answer: string;
  }>;
}

function formatEiAnswer(question: EIQuestion, value: unknown): string | null {
  if (value == null || value === '') return null;
  if (question.type === 'yes_no') {
    if (value === true || value === 'yes') return 'Yes';
    if (value === false || value === 'no') return 'No';
  }
  if (question.type === 'text_list' && Array.isArray(value)) {
    const items = value.filter((item) => String(item).trim().length > 0);
    return items.length > 0 ? items.join(', ') : null;
  }
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'number' && question.options?.[value] != null) {
    return question.options[value];
  }
  return String(value);
}

export function buildSanitizedEiSectionAnswers(
  responses: Record<string, unknown>,
): SanitizedSectionAnswer[] {
  return EARLY_INTERVENTION_SECTIONS.map((section) => ({
    sectionId: section.id,
    sectionTitle: section.title,
    answers: section.questions
      .map((question) => {
        const answer = formatEiAnswer(question, responses[question.id]);
        if (answer == null) return null;
        return {
          questionId: question.id,
          question: question.text,
          answer,
        };
      })
      .filter((entry): entry is NonNullable<typeof entry> => entry != null),
  })).filter((section) => section.answers.length > 0);
}
