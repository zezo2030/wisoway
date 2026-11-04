import { BadRequestException } from '@nestjs/common';

/** CliQ is Jordanian: only JOD fares can be collected through it. */
export const CLIQ_CURRENCIES: readonly string[] = ['JOD'];

/**
 * Where a CliQ request-to-pay is sent: a CliQ alias (e.g. `ahmad@cliq`) or a
 * Jordanian mobile in the `00962XXXXXXXXX` form uWallet expects. People type
 * numbers every which way, so local and international forms, Arabic numerals
 * and the invisible marks a pasted number carries are folded into that shape.
 */
export type CliqPayer = { type: 'ALIAS' | 'MOBL'; value: string };

const ALIAS_PATTERN = /^[A-Za-z0-9._@-]{3,100}$/;

function cleanCliqInput(raw: string): string {
  return raw
    .replace(/[\u200e\u200f\u202a-\u202e\u2066-\u2069]/g, '')
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .trim();
}

export function parseCliqPayer(
  raw: string | null | undefined,
): CliqPayer | null {
  const cleaned = cleanCliqInput(raw ?? '');
  const text = cleaned.replace(/[\s-]/g, '');
  if (!text) return null;

  if (/^(\+|00)?\d{9,15}$/.test(text)) {
    let digits = text.replace(/^\+/, '').replace(/^00/, '');
    if (/^07\d{8}$/.test(digits)) digits = `962${digits.slice(1)}`; // 07X…
    if (/^7\d{8}$/.test(digits)) digits = `962${digits}`; // 7X… without 0
    if (!/^962\d{9}$/.test(digits)) return null;
    return { type: 'MOBL', value: `00${digits}` };
  }

  return ALIAS_PATTERN.test(cleaned) ? { type: 'ALIAS', value: cleaned } : null;
}

/**
 * The recipient of a request where the user chose the kind themselves (wallet
 * top-up); a mobile is refused here rather than by the bank.
 */
export function resolveCliqRecipient(
  type: CliqPayer['type'],
  value: string,
): CliqPayer {
  if (type === 'ALIAS') return { type, value: cleanCliqInput(value) };

  const payer = parseCliqPayer(value);
  if (payer?.type !== 'MOBL') {
    throw new BadRequestException(
      'أدخل رقم جوال أردنياً مسجّلاً في CliQ، مثل 0791234567.',
    );
  }
  return payer;
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
): { method: 'cash' | 'cliq' | 'wallet'; payerCliqAlias: string | null } {
  if (method === 'wallet') return { method: 'wallet', payerCliqAlias: null };
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
      'أدخل اسم CliQ أو رقم جوال أردنياً مسجّلاً في CliQ لإرسال طلب الدفع.',
    );
  }
  return { method: 'cliq', payerCliqAlias: payer.value };
}
