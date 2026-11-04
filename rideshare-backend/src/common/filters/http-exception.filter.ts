import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/** Nest's own exception body keys, and those this filter writes itself. */
const ENVELOPE_KEYS = new Set(['statusCode', 'message', 'error', 'success']);

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.message
        : 'Internal server error';

    const details = this.getErrorDetails(exception);
    const isDev = process.env.NODE_ENV !== 'production';
    const errorResponse: Record<string, unknown> = {
      success: false,
      ...this.getBusinessFields(exception),
      error: {
        code: status,
        message,
        details: details ?? null,
        timestamp: new Date().toISOString(),
        path: request.url,
        method: request.method,
      },
    };
    if (
      status === HttpStatus.INTERNAL_SERVER_ERROR &&
      isDev &&
      exception instanceof Error
    ) {
      (errorResponse.error as Record<string, unknown>).debug =
        exception.message;
      (errorResponse.error as Record<string, unknown>).stack = exception.stack;
    }

    // Log the error
    this.logger.error(
      `${request.method} ${request.url} - Status: ${status} - Message: ${message}`,
      exception instanceof Error ? exception.stack : undefined,
    );

    response.status(status).json(errorResponse);
  }

  /**
   * The string `code` a service threw, with the fields that go with it (ban
   * reason, charge totals…). Clients branch on these at the top of the body;
   * `error.code` stays the HTTP status.
   */
  private getBusinessFields(exception: unknown): Record<string, unknown> {
    if (!(exception instanceof HttpException)) return {};
    const response = exception.getResponse();
    if (typeof response !== 'object' || response === null) return {};

    const fields = response as Record<string, unknown>;
    if (typeof fields['code'] !== 'string') return {};

    return Object.fromEntries(
      Object.entries(fields).filter(([key]) => !ENVELOPE_KEYS.has(key)),
    );
  }

  private getErrorDetails(exception: unknown): any {
    if (exception instanceof HttpException) {
      const response = exception.getResponse();
      if (typeof response === 'string') {
        return null;
      }
      if (typeof response === 'object' && response !== null) {
        const r = response as Record<string, unknown>;
        const err = r['error'] as Record<string, unknown> | undefined;
        if (err && Array.isArray(err['details'])) {
          return err['details'];
        }
        if ('message' in r) {
          return r['message'];
        }
      }
    }
    return null;
  }
}
