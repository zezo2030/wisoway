import type { CreateNotificationDto } from '../notifications/dto/create-notification.dto';

/** The wallet top-up fields a notice needs. */
interface TopupLike {
  id: string;
  userId: string;
  amount: number | string;
  currency?: string | null;
}

const amountText = (p: TopupLike) =>
  `${Number(p.amount)} ${p.currency ?? ''}`.trim();

/**
 * What the user is told once a top-up reaches their wallet. The types are
 * the ones the app already opens on the payment history.
 */
export function topupCreditedNotice(p: TopupLike): CreateNotificationDto {
  return {
    userId: p.userId,
    type: 'payment_approved',
    title: 'تم شحن محفظتك',
    body: `أُضيف ${amountText(p)} إلى رصيد محفظتك.`,
    data: { paymentId: p.id, paymentType: 'wallet_topup' },
  };
}

export function topupRejectedNotice(
  p: TopupLike,
  note?: string | null,
): CreateNotificationDto {
  const reason = note?.trim();
  return {
    userId: p.userId,
    type: 'payment_rejected',
    title: 'لم يُقبل طلب شحن المحفظة',
    body: reason
      ? `طلب شحن ${amountText(p)} لم يُقبل. السبب: ${reason}`
      : `طلب شحن ${amountText(p)} لم يُقبل. تواصل مع الدعم لمعرفة السبب.`,
    data: { paymentId: p.id, paymentType: 'wallet_topup' },
  };
}
