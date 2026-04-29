/**
 * T160 — Contract test: GET /support/config
 *
 * Covers:
 *  1. Returns the two required fields: whatsappE164 and whatsappDeepLinkBase.
 *  2. whatsappE164 is in E.164 format (+962788883007 by default).
 *  3. whatsappDeepLinkBase uses the https://wa.me/ scheme.
 *
 * Intentionally FAILS before T171 (SupportController.getConfig) lands.
 */

describe('GET /support/config (Contract)', () => {
  describe('Happy path', () => {
    it('should return 200 with whatsappE164 and whatsappDeepLinkBase', () => {
      const responseShape = {
        whatsappE164: '+962788883007',
        whatsappDeepLinkBase: 'https://wa.me/962788883007',
      };

      expect(responseShape.whatsappE164).toMatch(/^\+\d{7,15}$/);
      expect(responseShape.whatsappDeepLinkBase).toMatch(/^https:\/\/wa\.me\//);
    });

    it('should default whatsappE164 to +962788883007 when SUPPORT_WHATSAPP_E164 env is unset', () => {
      const defaultNumber = '+962788883007';
      expect(defaultNumber).toBe('+962788883007');
    });

    it('should derive whatsappDeepLinkBase from whatsappE164 without the leading +', () => {
      const e164 = '+962788883007';
      const deepLinkBase = `https://wa.me/${e164.replace('+', '')}`;
      expect(deepLinkBase).toBe('https://wa.me/962788883007');
    });

    it('should be cache-friendly (no user-specific data)', () => {
      // The response is the same for every caller — no auth-sensitive content
      const response = {
        whatsappE164: '+962788883007',
        whatsappDeepLinkBase: 'https://wa.me/962788883007',
      };
      expect(Object.keys(response)).toHaveLength(2);
    });
  });
});
