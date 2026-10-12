import { BadRequestException } from '@nestjs/common';

/** CliQ is Jordanian: only JOD fares can be collected through it. */
export const CLIQ_CURRENCIES: readonly string[] = ['JOD'];

/**
 * Where a CliQ request-to-pay is sent: a CliQ alias (e.g. `ahmad@cliq`) or a
 * Jordanian mobile in the `00962XXXXXXXXX` form uWallet expects. Passengers
 * type numbers every which way, so local and international forms are folded
 * into that one shape.
 */
export type CliqPayer = { type: 'ALIAS' | 'MOBL'; value: string };

const ALIAS_PATTERN = /^[A-Za-z0-9._@-]{3,100}$/;

export function parseCliqPayer(raw: string | null | undefined): CliqPayer | null {
  const text = raw?.trim().replace(/[\s-]/g, '') ?? '';
  if (!text) return null;

  if (/^(\+|00)?\d{9,15}$/.test(text)) {
    let digits = text.replace(/^\+/, '').replace(/^00/, '');
    if (/^07\d{8}$/.test(digits)) digits = `962${digits.slice(1)}`; // 07X…
    if (/^7\d{8}$/.test(digits)) digits = `962${digits}`; // 7X… without 0
    if (!/^962\d{9}$/.test(digits)) return null;
    return { type: 'MOBL', value: `00${digits}` };
  }

  return ALIAS_PATTERN.test(raw!.trim())
    ? { type: 'ALIAS', value: raw!.trim() }
    : null;
}

/**
 * Validates a passenger's payment choice when they book or request a ride.
 * Returns the normalized payer for CliQ (null for cash); throws on a choice
 * that can't be honoured here.
 */
export function resolvePaymentChoice(
  method: string | undefined,
  currency: string,
  payerAlias: string | null | undefined,
): { method: 'cash' | 'cliq'; payerCliqAlias: string | null } {
  if (!method || method === 'cash') {
    return { method: 'cash', payerCliqAlias: null };
  }
  if (method !== 'cliq') {
    throw new BadRequestException('طريقة الدفع غير مدعومة.');
  }
  if (!CLIQ_CURRENCIES.includes(currency?.toUpperCase())) {
    throw new BadRequestException(
      'الدفع عبر CliQ متاح فقط للرحلات داخل الأردن.',
    );
  }
  const payer = parseCliqPayer(payerAlias);
  if (!payer) {
    throw new BadRequestException(
      'أدخل اسم CliQ أو رقم جوالك المسجّل في CliQ لإرسال طلب الدفع.',
    );
  }
  return { method: 'cliq', payerCliqAlias: payer.value };
}