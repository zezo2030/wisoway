import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { BadRequestException } from '@nestjs/common';
import { A2aCliqService } from './a2a-cliq.service';

jest.mock('axios', () => ({
  post: jest.fn(),
}));

import axios from 'axios';

describe('A2aCliqService', () => {
  let service: A2aCliqService;

  const mockConfig: Record<string, string> = {
    BASE_URL: 'https://testapi.uwallet.jo/A2AMerchantInterface',
    MERCHANT_ID: 'ARABTHERAP',
    USER_ID: 'UWallet_UAT',
    PASSWORD: 'password',
    SECURITY_KEY: 'security-key',
    CORRELATION_ID: 'ARABTHERAP',
    BEARER_TOKEN: 'test-token',
    CALLBACK_URL: 'https://example.com/callback',
  };

  beforeEach(async () => {
    (axios.post as jest.Mock).mockReset();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        A2aCliqService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn(() => mockConfig),
          },
        },
      ],
    }).compile();

    service = module.get<A2aCliqService>(A2aCliqService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getToken', () => {
    it('should return token on success', async () => {
      (axios.post as jest.Mock).mockResolvedValue({
        data: {
          TokenInfo: {
            Token: 'jwt-token',
            ExpiryDate: '2025-01-01T00:00:00',
          },
          Result: {
            errorCode: 0,
            description: 'Success',
          },
        },
      });

      const result = await service.getToken();
      expect(result.token).toBe('jwt-token');
    });

    it('should throw on invalid response', async () => {
      (axios.post as jest.Mock).mockResolvedValue({
        data: {},
      });

      await expect(service.getToken()).rejects.toThrow(BadRequestException);
    });
  });

  describe('purchase', () => {
    it('should return purchase response on success', async () => {
      (axios.post as jest.Mock).mockResolvedValue({
        data: {
          errorCode: 0,
          description: 'Success',
        },
      });

      const result = await service.purchase({
        messageTrxId: 'CLIQ123',
        aliasType: 'MOBL',
        aliasValue: '0096278xxxxxxx',
        amount: 1,
      });

      expect(result.errorCode).toBe(0);
    });

    it('should throw on invalid response', async () => {
      (axios.post as jest.Mock).mockResolvedValue({
        data: null,
      });

      await expect(
        service.purchase({
          messageTrxId: 'CLIQ123',
          aliasType: 'MOBL',
          aliasValue: '0096278xxxxxxx',
          amount: 1,
        }),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('paymentInquiry', () => {
    it('should return inquiry response on success', async () => {
      (axios.post as jest.Mock).mockResolvedValue({
        data: {
          MessageTrxID: 'CLIQ123',
          StatusCode: '0',
          StatusDescription: 'Success',
        },
      });

      const result = await service.paymentInquiry('CLIQ123');
      expect(result.StatusCode).toBe('0');
    });

    it('should throw on invalid response', async () => {
      (axios.post as jest.Mock).mockResolvedValue({
        data: {},
      });

      await expect(service.paymentInquiry('CLIQ123')).rejects.toThrow(
        BadRequestException,
      );
    });
  });
}

