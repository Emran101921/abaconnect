import {
  encodeSharedDocumentIds,
  parseSharedDocumentIds,
} from './marketplace-consent.util';

describe('marketplace consent document encoding', () => {
  it('round-trips document ids', () => {
    const ids = ['doc-1', 'doc-2'];
    const encoded = encodeSharedDocumentIds(ids);
    expect(parseSharedDocumentIds(encoded)).toEqual(ids);
  });

  it('returns empty list for missing or invalid device info', () => {
    expect(parseSharedDocumentIds(null)).toEqual([]);
    expect(parseSharedDocumentIds('')).toEqual([]);
    expect(parseSharedDocumentIds('not-json')).toEqual([]);
    expect(parseSharedDocumentIds('{}')).toEqual([]);
    expect(parseSharedDocumentIds('{"documentIds":"x"}')).toEqual([]);
  });

  it('coerces document ids to strings', () => {
    const encoded = JSON.stringify({ documentIds: [1, 2] });
    expect(parseSharedDocumentIds(encoded)).toEqual(['1', '2']);
  });
});
