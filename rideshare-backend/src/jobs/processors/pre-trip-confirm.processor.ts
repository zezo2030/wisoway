import { Processor, Process } from '@nestjs/bull';
import type { Job } from 'bull';
import { Logger } from '@nestjs/common';
import { PreTripReminderJob } from '../pre-trip-reminder.job';

/**
 * Queue entry point kept for any `send-prompts` job already enqueued. The
 * reminders themselves are sent by {@link PreTripReminderJob}, which also
 * sweeps for due trips every minute.
 */
@Processor('pre-trip-confirm')
export class PreTripConfirmProcessor {
  private readonly logger = new Logger(PreTripConfirmProcessor.name);

  constructor(private readonly reminders: PreTripReminderJob) {}

  @Process('send-prompts')
  async handlePreTripConfirm(job: Job<{ tripId: string }>) {
    const sent = await this.reminders.remind(job.data.tripId);
    this.logger.log(
      `Pre-trip reminder for trip ${job.data.tripId}: ${sent ? 'sent' : 'already sent'}`,
    );
  }
}
