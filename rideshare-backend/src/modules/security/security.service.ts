import { Injectable } from '@nestjs/common';

@Injectable()
export class SecurityService {
  private readonly abuseWindowMs = 60_000;
  private readonly abuseMap = new Map<
    string,
    { count: number; resetAt: number }
  >();

  registerAction(key: string, maxPerWindow = 30): boolean {
    const now = Date.now();
    const current = this.abuseMap.get(key);
    if (!current || now >= current.resetAt) {
      this.abuseMap.set(key, { count: 1, resetAt: now + this.abuseWindowMs });
      return true;
    }
    current.count += 1;
    return current.count <= maxPerWindow;
  }
}
