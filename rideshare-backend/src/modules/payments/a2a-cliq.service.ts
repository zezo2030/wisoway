import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

interface A2aCliqTokenResponse {
  TokenInfo: {
    Token: string;
    ExpiryDate: string;
  };
  Result: {
    errorCode: number | string;
    description: string;
  };
}

interface A2aCliqPurchaseResponse {
  errorCode: number | string;
  description: string;
  description_ar?: string;
  MSGID?: string | null;
}

interface A2aCliqInquiryResponse {
  MessageTrxID: string;
  RAliasValue?: string;
  Amount?: number;
  StatusCode: string;
  StatusDescription: string;
  StatusDescription_ar?: string;
  MSGID?: string;
  errorCode?: number | string;
  description?: string;
}

function isHttp401(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const status = (error as { response?: { status?: number } }).response?.status;
  return status === 401;
}

@Injectable()
export class A2aCliqService {
  private readonly logger = new Logger(A2aCliqService.name);
  private readonly baseUrl: string;
  private readonly merchantId: string;
  private readonly userId: string;
  private readonly password: string;
  private readonly securityKey: string;
  private readonly correlationId: string;
  /** Bearer لـ Purchase / PaymentInquiry fallback (من Postman "Purchase") */
  private readonly staticBearerToken: string;
  /** Bearer لطلب GetToken فقط (من Postman "Get Token") */
  private readonly bearerForGetToken: string;
  private readonly callbackUrl: string;

  /** Cached session token obtained from GetToken */
  private cachedToken: string | null = null;
  private tokenExpiresAt: Date | null = null;

  constructor(private readonly configService: ConfigService) {
    const cfg = this.configService.get('a2aCliq') as Record<string, string>;

    this.baseUrl = cfg?.BASE_URL;
    this.merchantId = cfg?.MERCHANT_ID;
    this.userId = cfg?.USER_ID;
    this.password = cfg?.PASSWORD;
    this.securityKey = cfg?.SECURITY_KEY;
    this.correlationId = cfg?.CORRELATION_ID;
    this.staticBearerToken = cfg?.BEARER_TOKEN;
    this.bearerForGetToken = cfg?.BEARER_TOKEN_GETTOKEN || cfg?.BEARER_TOKEN;
    this.callbackUrl = cfg?.CALLBACK_URL;

    if (!this.baseUrl || !this.merchantId || !this.securityKey) {
      this.logger.warn('A2A CliQ config is incomplete');
    }
  }

  private getBaseHeaders(): Record<string, string> {
    return {
      CorrelationID: this.correlationId,
      MerchantID: this.merchantId,
      UserID: this.userId,
      Password: this.password,
      'Content-Type': 'application/json',
    };
  }

  /** Returns true when the cached session token is still valid (>60s buffer). */
  private isCachedTokenValid(): boolean {
    if (!this.cachedToken || !this.tokenExpiresAt) return false;
    const t = this.tokenExpiresAt.getTime();
    if (Number.isNaN(t)) return false;
    return t - Date.now() > 60_000;
  }

  private invalidateTokenCache(): void {
    this.cachedToken = null;
    this.tokenExpiresAt = null;
  }

  private buildHeadersWithBearer(bearer: string): Record<string, string> {
    return {
      ...this.getBaseHeaders(),
      Authorization: `Bearer ${bearer}`,
    };
  }

  /**
   * Calls GetToken with a given Authorization bearer (JWT from Postman).
   */
  private async fetchGetTokenWithBearer(
    bearer: string,
  ): Promise<{ token: string; expiryDate: string }> {
    const url = `${this.baseUrl}/GetToken`;
    const response = await axios.post<A2aCliqTokenResponse>(
      url,
      { SecurityKey: this.securityKey },
      {
        headers: {
          ...this.getBaseHeaders(),
          Authorization: `Bearer ${bearer}`,
        },
      },
    );

    const data = response.data;

    if (!data?.TokenInfo?.Token) {
      throw new BadRequestException('Invalid token response from A2A CliQ');
    }
    if (Number(data.Result?.errorCode) !== 0) {
      throw new BadRequestException(
        `A2A CliQ token error: ${data.Result?.description || 'Unknown error'}`,
      );
    }

    this.cachedToken = data.TokenInfo.Token;
    this.tokenExpiresAt = new Date(data.TokenInfo.ExpiryDate);
    this.logger.log(
      `A2A CliQ token refreshed, expires at ${data.TokenInfo.ExpiryDate}`,
    );

    return {
      token: data.TokenInfo.Token,
      expiryDate: data.TokenInfo.ExpiryDate,
    };
  }

  /**
   * Gets a fresh session token from GetToken.
   * يستخدم BEARER_TOKEN_GETTOKEN أولاً؛ عند 401 يُعاد المحاولة بـ BEARER_TOKEN (كما في Postman إن انتهى توكن Get Token).
   */
  async getToken(): Promise<{ token: string; expiryDate: string }> {
    try {
      return await this.fetchGetTokenWithBearer(this.bearerForGetToken);
    } catch (first: unknown) {
      const canRetry =
        isHttp401(first) &&
        this.staticBearerToken?.trim() &&
        this.bearerForGetToken !== this.staticBearerToken;
      if (canRetry) {
        this.logger.warn(
          'GetToken returned 401 with A2A_CLIQ_BEARER_TOKEN_GETTOKEN; retrying with A2A_CLIQ_BEARER_TOKEN',
        );
        try {
          return await this.fetchGetTokenWithBearer(this.staticBearerToken);
        } catch (second: unknown) {
          this.logger.error(
            `Failed to get A2A CliQ token: ${second instanceof Error ? second.message : String(second)}`,
          );
          if (second instanceof BadRequestException) throw second;
          throw new BadRequestException('Failed to get A2A CliQ token');
        }
      }
      this.logger.error(
        `Failed to get A2A CliQ token: ${first instanceof Error ? first.message : String(first)}`,
      );
      if (first instanceof BadRequestException) throw first;
      throw new BadRequestException('Failed to get A2A CliQ token');
    }
  }

  /**
   * Returns a valid session JWT from GetToken (cached until shortly before expiry).
   */
  private async ensureSessionToken(): Promise<string> {
    if (this.isCachedTokenValid()) {
      return this.cachedToken!;
    }
    const { token } = await this.getToken();
    return token;
  }

  /**
   * POST to CliQ with auth retry: some uwallet deployments accept only the
   * short-lived session token, others accept the long-lived merchant JWT for
   * Purchase/Inquiry. On 401 we invalidate cache, refresh GetToken, then try
   * the static A2A_CLIQ_BEARER_TOKEN once.
   */
  private async postCliq<T>(
    path: string,
    body: unknown,
    operation: string,
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    let lastError: unknown;

    const strategies: Array<{ name: string; bearer: () => Promise<string> }> = [
      {
        name: 'session',
        bearer: async () => this.ensureSessionToken(),
      },
      {
        name: 'fresh_session',
        bearer: async () => {
          this.invalidateTokenCache();
          const { token } = await this.getToken();
          return token;
        },
      },
      {
        name: 'static_merchant_jwt',
        bearer: async () => {
          if (!this.staticBearerToken?.trim()) {
            throw new BadRequestException(
              'A2A_CLIQ_BEARER_TOKEN is not configured',
            );
          }
          return this.staticBearerToken;
        },
      },
    ];

    for (let i = 0; i < strategies.length; i++) {
      try {
        const bearer = await strategies[i].bearer();
        const response = await axios.post<T>(url, body, {
          headers: this.buildHeadersWithBearer(bearer),
        });
        return response.data;
      } catch (error: unknown) {
        lastError = error;
        const is401 = isHttp401(error);
        if (is401 && i < strategies.length - 1) {
          this.logger.warn(
            `A2A CliQ ${operation}: 401 with ${strategies[i].name}, retrying with next strategy`,
          );
          continue;
        }
        throw error;
      }
    }

    throw lastError;
  }

  async purchase(params: {
    messageTrxId: string;
    aliasType: 'ALIAS' | 'MOBL';
    aliasValue: string;
    amount: number;
    callbackUrl?: string;
  }): Promise<A2aCliqPurchaseResponse> {
    const { messageTrxId, aliasType, aliasValue, amount, callbackUrl } = params;

    try {
      const data = await this.postCliq<A2aCliqPurchaseResponse>(
        '/Purchase',
        {
          MessageTrxID: messageTrxId,
          MerchantID: this.merchantId,
          RAliasType: aliasType,
          RAliasValue: aliasValue,
          Amount: amount,
          CallBackURL: callbackUrl || this.callbackUrl,
        },
        'Purchase',
      );

      if (data == null || typeof data.errorCode === 'undefined') {
        throw new BadRequestException(
          'Invalid purchase response from A2A CliQ',
        );
      }

      return data;
    } catch (error: unknown) {
      const msg = isHttp401(error)
        ? 'رفضت بوابة CliQ المصادقة (401). تحقق من A2A_CLIQ_BEARER_TOKEN وصلاحية التوكن.'
        : error instanceof Error
          ? error.message
          : String(error);
      this.logger.error(`Failed to create A2A CliQ purchase: ${msg}`);
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException(
        isHttp401(error)
          ? 'رفضت بوابة CliQ المصادقة. راجع إعدادات A2A_CLIQ في البيئة.'
          : 'Failed to create A2A CliQ purchase',
      );
    }
  }

  /**
   * استعلام حالة الدفع. يستخدم validateStatus مرنًا حتى لا يفشل الطلب عند 400 مع errorCode 306 في الجسم.
   */
  async paymentInquiry(messageTrxId: string): Promise<A2aCliqInquiryResponse> {
    const url = `${this.baseUrl}/PaymentInquiry`;
    const body = { MessageTrxID: messageTrxId };

    const strategies: Array<{ name: string; bearer: () => Promise<string> }> = [
      { name: 'session', bearer: async () => this.ensureSessionToken() },
      {
        name: 'fresh_session',
        bearer: async () => {
          this.invalidateTokenCache();
          const { token } = await this.getToken();
          return token;
        },
      },
      {
        name: 'static_merchant_jwt',
        bearer: async () => {
          if (!this.staticBearerToken?.trim()) {
            throw new BadRequestException(
              'A2A_CLIQ_BEARER_TOKEN is not configured',
            );
          }
          return this.staticBearerToken;
        },
      },
    ];

    let lastError: unknown;
    for (let i = 0; i < strategies.length; i++) {
      try {
        const bearer = await strategies[i].bearer();
        const response = await axios.post<
          A2aCliqInquiryResponse & { errorCode?: number }
        >(url, body, {
          headers: this.buildHeadersWithBearer(bearer),
          validateStatus: () => true,
        });
        const data = response.data;
        const ok = response.status >= 200 && response.status < 300;

        if (!ok) {
          const code =
            data?.errorCode != null
              ? String(data.errorCode)
              : String(response.status);
          return {
            MessageTrxID: messageTrxId,
            StatusCode: code,
            StatusDescription:
              (data as { description?: string })?.description ||
              `HTTP ${response.status}`,
            StatusDescription_ar: (data as { description_ar?: string })
              ?.description_ar,
          };
        }

        if (data && data.StatusCode != null) {
          return data;
        }

        if (data && (data as { errorCode?: number }).errorCode != null) {
          const ec = String((data as { errorCode?: number }).errorCode);
          return {
            MessageTrxID: messageTrxId,
            StatusCode: ec,
            StatusDescription:
              (data as { description?: string }).description || 'Inquiry error',
            StatusDescription_ar: (data as { description_ar?: string })
              .description_ar,
          };
        }

        throw new BadRequestException('Invalid inquiry response from A2A CliQ');
      } catch (error: unknown) {
        lastError = error;
        if (isHttp401(error) && i < strategies.length - 1) {
          this.logger.warn(
            `A2A CliQ PaymentInquiry: 401 with ${strategies[i].name}, retrying`,
          );
          continue;
        }
        const msg = error instanceof Error ? error.message : String(error);
        this.logger.error(`Failed to inquire A2A CliQ payment: ${msg}`);
        if (error instanceof BadRequestException) throw error;
        throw new BadRequestException('Failed to inquire A2A CliQ payment');
      }
    }
    throw lastError;
  }
}
