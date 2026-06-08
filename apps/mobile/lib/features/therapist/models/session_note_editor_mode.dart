enum SessionNoteEditorMode { therapist, agency, admin }

class SessionNoteScreenRequest {
  const SessionNoteScreenRequest({
    required this.sessionId,
    this.mode = SessionNoteEditorMode.therapist,
  });

  final String sessionId;
  final SessionNoteEditorMode mode;

  bool get canEditWhenFullySigned => mode != SessionNoteEditorMode.therapist;

  @override
  bool operator ==(Object other) =>
      other is SessionNoteScreenRequest &&
      other.sessionId == sessionId &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(sessionId, mode);
}
