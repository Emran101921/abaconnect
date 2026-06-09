import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/therapist/models/eip_session_note_model.dart';

EipSessionNoteModel completeNote({String sessionId = 'session-1'}) {
  return EipSessionNoteModel(
    sessionId: sessionId,
    childName: 'Alex Smith',
    childDob: '2020-01-01',
    childSex: 'Male',
    interventionistName: 'Dr. Jane Doe',
    credentials: 'SLP',
    npi: '1234567893',
    licenseNumber: 'SLP-123456',
    serviceType: 'Speech',
    sessionDate: '2026-06-03',
    ifspServiceLocation: 'Home',
    timeFrom: '9:00',
    timeTo: '10:00',
    intensity: 'Home/Community',
    sessionDelivered: 'In-person',
    dateNoteWritten: '2026-06-03',
    icd10Code: 'F80.2',
    participantChild: true,
    participantParent: true,
    q1IfspOutcomes: 'Outcome 1',
    q2SessionDescription: 'Worked on communication.',
    q3ObservedRoutines: true,
    q4HomeStrategies: 'Practice daily.',
    parentRelationship: 'Mother',
  );
}

void main() {
  group('EipSessionNoteModel parent signature gating', () {
    test('blocks parent signature when required fields are missing', () {
      const note = EipSessionNoteModel(sessionId: 'session-1');

      expect(note.isReadyForParentSignature, isFalse);
      expect(note.missingFieldsForParentSignature(), isNotEmpty);
      expect(note.missingFieldsForParentSignature(), contains('Child\'s name'));
    });

    test('allows parent signature when all required fields are present', () {
      final note = completeNote();

      expect(note.missingFieldsForParentSignature(), isEmpty);
      expect(note.isReadyForParentSignature, isTrue);
    });

    test('requires relationship to child before parent signature', () {
      final note = completeNote().copyWith(parentRelationship: '');

      expect(note.isReadyForParentSignature, isFalse);
      expect(
        note.missingFieldsForParentSignature(),
        contains('Relationship to child'),
      );
    });
  });

  group('EipSessionNoteModel lock state', () {
    test('is not fully signed without GPS-verified signatures', () {
      final note = completeNote().copyWith(
        interventionistSignature: 'Dr. Jane Doe',
        parentSignature: 'Parent Name',
      );

      expect(note.isFullySigned, isFalse);
      expect(note.hasInvalidSignatures, isTrue);
    });

    test('is fully signed when both parties sign with GPS coordinates', () {
      final note = completeNote().copyWith(
        interventionistSignature: 'Dr. Jane Doe',
        interventionistSignatureLatitude: 40.7128,
        interventionistSignatureLongitude: -74.006,
        parentSignature: 'Parent Name',
        parentSignatureLatitude: 40.7128,
        parentSignatureLongitude: -74.006,
      );

      expect(note.hasGpsVerifiedInterventionistSignature, isTrue);
      expect(note.hasGpsVerifiedParentSignature, isTrue);
      expect(note.isFullySigned, isTrue);
      expect(note.hasInvalidSignatures, isFalse);
    });
  });
}
