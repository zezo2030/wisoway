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
   * يطلب session token جديد من /GetToken.
   * uWallet لا يتطلب Authorization header لهذا الطلب — المصادقة تتم عبر:
   *   - Headers: CorrelationID, MerchantID, UserID, Password
   *   - Body:    SecurityKey
   * التوكن العائد صالح لمدة ~24 ساعة ويُستخدم كـ Bearer لباقي الطلبات.
   */
  async getToken(): Promise<{ token: string; expiryDate: string }> {
    const url = `${this.baseUrl}/GetToken`;
    try {
      const response = await axios.post<A2aCliqTokenResponse>(
        url,
        { SecurityKey: this.securityKey },
        { headers: this.getBaseHeaders() },
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
    } catch (error: unknown) {
      this.logger.error(
        `Failed to get A2A CliQ token: ${error instanceof Error ? error.message : String(error)}`,
      );
      if (error instanceof BadRequestException) throw error;
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
   * POST to CliQ. عند 401 نُبطل الكاش ونعيد طلب توكن جديد ثم نحاول مرة واحدة فقط.
   */
  private async postCliq<T>(
    path: string,
    body: unknown,
    operation: string,
    timeoutMs?: number,
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;

    const attempt = async (forceRefresh: boolean): Promise<T> => {
      if (forceRefresh) this.invalidateTokenCache();
      const bearer = await this.ensureSessionToken();
      const response = await axios.post<T>(url, body, {
        headers: this.buildHeadersWithBearer(bearer),
        ...(timeoutMs ? { timeout: timeoutMs } : {}),
      });
      return response.data;
    };

    try {
      return await attempt(false);
    } catch (error: unknown) {
      if (isHttp401(error)) {
        this.logger.warn(
          `A2A CliQ ${operation}: 401 with cached session token, refreshing and retrying`,
        );
        return attempt(true);
      }
      throw error;
    }
  }

  /**
   * يبدأ عملية Purchase. لا يفشل إذا حدث timeout — الـ uWallet قد يكمل العملية في الخلفية.
   * الحالة النهائية لازم تُحدد عبر paymentInquiry/awaitFinalStatus.
   *
   * يُعيد:
   *  - errorCode: '0' أو 'TIMEOUT' للحالات اللي لسه pending
   *  - description: وصف الحالة
   */
  async purchase(params: {
    messageTrxId: string;
    aliasType: 'ALIAS' | 'MOBL';
    aliasValue: string;
    amount: number;
    callbackUrl?: string;
    timeoutMs?: number;
  }): Promise<A2aCliqPurchaseResponse> {
    const {
      messageTrxId,
      aliasType,
      aliasValue,
      amount,
      callbackUrl,
      timeoutMs = 30_000,
    } = params;

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
        timeoutMs,
      );

      if (data == null || typeof data.errorCode === 'undefined') {
        throw new BadRequestException(
          'Invalid purchase response from A2A CliQ',
        );
      }

      return data;
    } catch (error: unknown) {
      // إذا كان timeout أو network error — العملية قد تكمل في الخلفية، فلا نعتبرها فشل نهائي.
      // المستدعي لازم يستخدم awaitFinalStatus لتحديد الحالة الفعلية عبر PaymentInquiry.
      const isTimeout =
        (error as { code?: string })?.code === 'ECONNABORTED' ||
        (error instanceof Error && /timeout/i.test(error.message ?? ''));
      if (isTimeout) {
        this.logger.warn(
          `A2A CliQ Purchase timed out for ${messageTrxId}; status must be resolved via PaymentInquiry`,
        );
        return {
          errorCode: 'TIMEOUT',
          description:
            'Purchase request timed out — final status must be determined via PaymentInquiry',
          MSGID: null,
        };
      }

      const msg = isHttp401(error)
        ? 'رفضت بوابة CliQ المصادقة (401). تحقق من بيانات A2A_CLIQ في البيئة.'
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
   * يستعلم بشكل دوري عن حالة العملية حتى:
   *   - يأتي StatusCode = "0" (نجاح أكيد ونهائي) → نخرج فوراً، أو
   *   - ينتهي الـ maxWaitMs → نُرجع آخر حالة معروفة (مع isTerminal=false إذا غير "0").
   *
   * ملاحظة مهمة: في uWallet، أكواد مثل "300" و "310" مش نهائية فعلاً —
   * شوهدت معاملات تنتقل من 310 → 300 → 0 بعد موافقة العميل المتأخرة.
   * لذلك نعتبر "0" فقط هي الحالة النهائية الإيجابية، وباقي الأكواد
   * نُبلغ عنها كـ "آخر حالة معروفة" بعد انتهاء الـ polling.
   * لو احتاج المستدعي يعتبر 200/300/310 رفض نهائي، يمكن فحص StatusCode بنفسه.
   *
   * @param messageTrxId الـ TrxID اللي بعتناه في Purchase
   * @param options.maxWaitMs الحد الأقصى لإجمالي وقت الانتظار (افتراضي 120 ثانية)
   * @param options.intervalMs الفترة بين كل استعلام (افتراضي 3 ثوانٍ)
   */
  async awaitFinalStatus(
    messageTrxId: string,
    options: { maxWaitMs?: number; intervalMs?: number } = {},
  ): Promise<
    A2aCliqInquiryResponse & { isTerminal: boolean; isSuccess: boolean }
  > {
    const maxWait = options.maxWaitMs ?? 120_000;
    const interval = options.intervalMs ?? 3_000;

    const deadline = Date.now() + maxWait;
    let lastResult: A2aCliqInquiryResponse | null = null;

    while (true) {
      try {
        lastResult = await this.paymentInquiry(messageTrxId);
        const code = String(lastResult.StatusCode ?? '');
        // فقط "0" هو terminal-success مؤكد
        if (code === '0') {
          return { ...lastResult, isTerminal: true, isSuccess: true };
        }
      } catch (e) {
        this.logger.warn(
          `awaitFinalStatus inquiry failed for ${messageTrxId}: ${e instanceof Error ? e.message : String(e)}`,
        );
      }

      if (Date.now() + interval > deadline) break;
      await new Promise((r) => setTimeout(r, interval));
    }

    // انتهى الوقت بدون نجاح. نُرجع آخر حالة. المستدعي يقرر هل يعيد المحاولة لاحقاً
    // (مثلاً يضع المعاملة في job يستعلم كل 5 دقائق لـ 24 ساعة) أم يعتبرها مرفوضة.
    return {
      MessageTrxID: messageTrxId,
      StatusCode: lastResult?.StatusCode ?? 'PENDING',
      StatusDescription:
        lastResult?.StatusDescription ??
        'Final status not reached within timeout',
      StatusDescription_ar: lastResult?.StatusDescription_ar,
      MSGID: lastResult?.MSGID,
      isTerminal: false,
      isSuccess: false,
    };
  }

  /**
   * يبدأ Purchase وينتظر الحالة النهائية عبر PaymentInquiry.
   * هذه هي الطريقة الموصى بها للاستخدام من الـ services الأعلى.
   */
  async purchaseAndAwait(params: {
    messageTrxId: string;
    aliasType: 'ALIAS' | 'MOBL';
    aliasValue: string;
    amount: number;
    callbackUrl?: string;
    purchaseTimeoutMs?: number;
    inquiryMaxWaitMs?: number;
    inquiryIntervalMs?: number;
  }): Promise<
    A2aCliqInquiryResponse & { isTerminal: boolean; isSuccess: boolean }
  > {
    const {
      purchaseTimeoutMs,
      inquiryMaxWaitMs,
      inquiryIntervalMs,
      ...purchaseParams
    } = params;

    // 1. ابعت Purchase (لا نهتم لو timeout)
    const purchaseResp = await this.purchase({
      ...purchaseParams,
      timeoutMs: purchaseTimeoutMs ?? 30_000,
    });

    // لو الـ Purchase رد فوراً بـ validation rejection (مثلاً 3010 self-payment، أو
    // أكواد رفض فورية محددة)، نعتبرها رفض نهائي بدون polling. الفرق عن أكواد
    // PaymentInquiry (300/310) إن دي بترجع من Purchase نفسه قبل ما PSP يشتغل.
    const purchaseErrorCode = String(purchaseResp.errorCode ?? '');
    const IMMEDIATE_REJECT_CODES = new Set([
      '3010', // CdtrAcct and DbtrAcct matched
    ]);
    if (IMMEDIATE_REJECT_CODES.has(purchaseErrorCode)) {
      return {
        MessageTrxID: params.messageTrxId,
        StatusCode: purchaseErrorCode,
        StatusDescription: purchaseResp.description || 'Purchase rejected',
        StatusDescription_ar: purchaseResp.description_ar,
        MSGID: purchaseResp.MSGID ?? undefined,
        isTerminal: true,
        isSuccess: false,
      };
    }

    // 2. استعلم لحد ما تجي حالة نهائية
    return this.awaitFinalStatus(params.messageTrxId, {
      maxWaitMs: inquiryMaxWaitMs,
      intervalMs: inquiryIntervalMs,
    });
  }

  /**
   * استعلام حالة الدفع. يستخدم validateStatus مرنًا حتى لا يفشل الطلب عند 400 مع errorCode 306 في الجسم.
   * عند 401 يُعاد طلب توكن جديد ومحاولة واحدة فقط.
   */
  async paymentInquiry(messageTrxId: string): Promise<A2aCliqInquiryResponse> {
    const url = `${this.baseUrl}/PaymentInquiry`;
    const body = { MessageTrxID: messageTrxId };

    const doRequest = async (forceRefresh: boolean) => {
      if (forceRefresh) this.invalidateTokenCache();
      const bearer = await this.ensureSessionToken();
      return axios.post<A2aCliqInquiryResponse & { errorCode?: number }>(
        url,
        body,
        {
          headers: this.buildHeadersWithBearer(bearer),
          validateStatus: () => true,
        },
      );
    };

    try {
      let response = await doRequest(false);

      // إذا كان 401 (مصادقة) — جدّد التوكن وحاول مرة واحدة
      if (response.status === 401) {
        this.logger.warn(
          'A2A CliQ PaymentInquiry: 401, refreshing token and retrying',
        );
        response = await doRequest(true);
      }

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
      const msg = error instanceof Error ? error.message : String(error);
      this.logger.error(`Failed to inquire A2A CliQ payment: ${msg}`);
      if (error instanceof BadRequestException) throw error;
      throw new BadRequestException('Failed to inquire A2A CliQ payment');
    }
  }
}
