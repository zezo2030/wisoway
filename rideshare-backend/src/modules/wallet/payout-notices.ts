import { PayoutStatus } from '../../database/entities';
import type { CreateNotificationDto } from '../notifications/dto/create-notification.dto';

/** What the driver is told when an admin acts on their payout request. */
export function payoutNotice(p: {
  id: string;
  driverId: string;
  amount: number | string;
  currency?: string | null;
  status: PayoutStatus;
  note?: string | null;
}): CreateNotificationDto | null {
  const amount = `${Number(p.amount)} ${p.currency ?? ''}`.trim();
  const data = { payoutId: p.id, status: p.status, screen: 'wallet' };
  switch (p.status) {
    case PayoutStatus.APPROVED:
      return {
        userId: p.driverId,
        type: 'payout_approved',
        title: 'تمت الموافقة على طلب السحب',
        body: `طلب سحب ${amount} مقبول، وسيُحوَّل إلى حسابك قريباً.`,
        data,
      };
    case PayoutStatus.PAID:
      return {
        userId: p.driverId,
        type: 'payout_paid',
        title: 'تم تحويل أرباحك',
        body: `حُوِّل ${amount} إلى حساب CliQ الخاص بك.`,
        data,
      };
    case PayoutStatus.REJECTED:
      return {
        userId: p.driverId,
        type: 'payout_rejected',
        title: 'لم يُقبل طلب السحب',
        body: p.note?.trim()
          ? `طلب سحب ${amount} لم يُقبل. السبب: ${p.note.trim()}`
          : `طلب سحب ${amount} لم يُقبل، وعاد المبلغ إلى رصيدك المتاح.`,
        data,
      };
    default:
      return null;
  }
}
