export function encodeSharedDocumentIds(documentIds: string[]): string {
  return JSON.stringify({ documentIds });
}

export function parseSharedDocumentIds(deviceInfo?: string | null): string[] {
  if (!deviceInfo?.trim()) return [];
  try {
    const parsed = JSON.parse(deviceInfo) as { documentIds?: unknown };
    if (!Array.isArray(parsed.documentIds)) return [];
    return parsed.documentIds.map((id) => String(id));
  } catch {
    return [];
  }
}
