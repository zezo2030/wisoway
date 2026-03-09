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

@Injectable()
export class A2aCliqService {
  private readonly logger = new Logger(A2aCliqService.name);
  private readonly baseUrl: string;
  private readonly merchantId: string;
  private readonly userId: string;
  private readonly password: string;
  private readonly securityKey: string;
  private readonly correlationId: string;
  private readonly bearerToken: string;
  private readonly callbackUrl: string;

  constructor(private readonly configService: ConfigService) {
    const cfg = this.configService.get('a2aCliq') as Record<string, string>;

    this.baseUrl = cfg?.BASE_URL;
    this.merchantId = cfg?.MERCHANT_ID;
    this.userId = cfg?.USER_ID;
    this.password = cfg?.PASSWORD;
    this.securityKey = cfg?.SECURITY_KEY;
    this.correlationId = cfg?.CORRELATION_ID;
    this.bearerToken = cfg?.BEARER_TOKEN;
    this.callbackUrl = cfg?.CALLBACK_URL;

    if (!this.baseUrl || !this.merchantId || !this.securityKey) {
      this.logger.warn('A2A CliQ config is incomplete');
    }
  }

  private getAuthHeaders(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.bearerToken}`,
      CorrelationID: this.correlationId,
      MerchantID: this.merchantId,
      UserID: this.userId,
      Password: this.password,
      'Content-Type': 'application/json',
    };
  }

  async getToken(): Promise<{ token: string; expiryDate: string }> {
    try {
      const url = `${this.baseUrl}/GetToken`;

      const response = await axios.post<A2aCliqTokenResponse>(
        url,
        {
          SecurityKey: this.securityKey,
        },
        {
          headers: this.getAuthHeaders(),
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

      return {
        token: data.TokenInfo.Token,
        expiryDate: data.TokenInfo.ExpiryDate,
      };
    } catch (error: any) {
      this.logger.error(
        `Failed to get A2A CliQ token: ${error.message || error}`,
      );
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to get A2A CliQ token');
    }
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
      const url = `${this.baseUrl}/Purchase`;

      const response = await axios.post<A2aCliqPurchaseResponse>(
        url,
        {
          MessageTrxID: messageTrxId,
          MerchantID: this.merchantId,
          RAliasType: aliasType,
          RAliasValue: aliasValue,
          Amount: amount,
          CallBackURL: callbackUrl || this.callbackUrl,
        },
        {
          headers: this.getAuthHeaders(),
        },
      );

      const data = response.data;

      if (data == null || typeof data.errorCode === 'undefined') {
        throw new BadRequestException(
          'Invalid purchase response from A2A CliQ',
        );
      }

      return data;
    } catch (error: any) {
      this.logger.error(
        `Failed to create A2A CliQ purchase: ${error.message || error}`,
      );
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to create A2A CliQ purchase');
    }
  }

  async paymentInquiry(messageTrxId: string): Promise<A2aCliqInquiryResponse> {
    try {
      const url = `${this.baseUrl}/PaymentInquiry`;

      const response = await axios.post<A2aCliqInquiryResponse>(
        url,
        {
          MessageTrxID: messageTrxId,
        },
        {
          headers: this.getAuthHeaders(),
        },
      );

      const data = response.data;

      if (!data || !data.StatusCode) {
        throw new BadRequestException('Invalid inquiry response from A2A CliQ');
      }

      return data;
    } catch (error: any) {
      this.logger.error(
        `Failed to inquire A2A CliQ payment: ${error.message || error}`,
      );
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to inquire A2A CliQ payment');
    }
  }
}
