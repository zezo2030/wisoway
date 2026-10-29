/**
 * HTTP client for the AMS SMSC (websmpp). Sends one plain SMS — unlike Twilio
 * Verify it neither issues nor checks codes, so the caller owns the OTP.
 */
export class AmsSmsClient {
  constructor(
    private readonly baseUrl: string,
    private readonly accessKey: string,
    private readonly senderId: string,
  ) {}

  /** Sends an Arabic (type 4) message. `&` and `#` are rejected by the SMSC. */
  async sendArabic(phoneNumber: string, text: string): Promise<string> {
    const params = new URLSearchParams({
      accesskey: this.accessKey,
      sid: this.senderId,
      mno: phoneNumber.replace(/^\+/, ''),
      type: '4',
      text,
    });
    const response = await fetch(`${this.baseUrl}/websms?${params}`, {
      signal: AbortSignal.timeout(10000),
    });
    const body = (await response.text()).trim();
    // Success is "Response: <messageId>"; failures are "ERROR - HTTPxx --> ...".
    const match = /^Response:\s*(\d+)/.exec(body);
    if (!response.ok || !match) {
      throw new Error(`AMS SMS rejected (${response.status}): ${body}`);
    }
    return match[1];
  }
}
