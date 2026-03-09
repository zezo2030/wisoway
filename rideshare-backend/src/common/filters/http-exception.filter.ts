import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

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

  private getErrorDetails(exception: unknown): any {
    if (exception instanceof HttpException) {
      const response = exception.getResponse();
      if (typeof response === 'string') {
        return null;
      }
      if (typeof response === 'object' && 'message' in response) {
        return (response as any).message;
      }
    }
    return null;
  }
}
