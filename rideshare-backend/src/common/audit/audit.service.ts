import { Injectable, Logger } from '@nestjs/common';

export interface AuditRecord {
  action: string;
  userId: string;
  [key: string]: any;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  emit(record: AuditRecord): void {
    const entry = {
      ...record,
      timestamp: new Date().toISOString(),
    };
    this.logger.log(JSON.stringify(entry));
  }
}
