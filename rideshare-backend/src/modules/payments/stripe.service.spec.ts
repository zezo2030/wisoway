import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { StripeService } from './stripe.service';
import { BadRequestException } from '@nestjs/common';

describe('StripeService', () => {
  let service: StripeService;
  let configService: ConfigService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        StripeService,
        {
          provide: ConfigService,
          useValue: {
            get: jest.fn((key: string) => {
              if (key === 'stripe.STRIPE_SECRET_KEY') {
                return 'sk_test_123';
              }
              if (key === 'stripe.STRIPE_WEBHOOK_SECRET') {
                return 'whsec_123';
              }
              return null;
            }),
          },
        },
      ],
    }).compile();

    service = module.get<StripeService>(StripeService);
    configService = module.get<ConfigService>(ConfigService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createPaymentIntent', () => {
    it('should create a payment intent successfully', async () => {
      // Mock the stripe client
      service['stripe'] = {
        paymentIntents: {
          create: jest.fn().mockResolvedValue({
            id: 'pi_123',
            client_secret: 'secret_123',
          }),
        },
      } as any;

      const result = await service.createPaymentIntent(100, 'egp', {
        bookingId: 'booking123',
      });

      expect(result).toEqual({
        clientSecret: 'secret_123',
        paymentIntentId: 'pi_123',
      });
    });

    it('should throw BadRequestException if Stripe is not configured', async () => {
      service['stripe'] = null as any;

      await expect(service.createPaymentIntent(100, 'egp')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException on Stripe API error', async () => {
      service['stripe'] = {
        paymentIntents: {
          create: jest.fn().mockRejectedValue(new Error('Stripe error')),
        },
      } as any;

      await expect(service.createPaymentIntent(100, 'egp')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should convert amount to cents', async () => {
      const mockCreate = jest.fn().mockResolvedValue({
        id: 'pi_123',
        client_secret: 'secret_123',
      });
      service['stripe'] = {
        paymentIntents: {
          create: mockCreate,
        },
      } as any;

      await service.createPaymentIntent(100.5, 'egp');

      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({
          amount: 10050, // 100.5 * 100
        }),
      );
    });
  });

  describe('handleWebhookEvent', () => {
    it('should construct and return valid webhook event', async () => {
      const mockEvent = {
        id: 'evt_123',
        type: 'payment_intent.succeeded',
        data: { object: { id: 'pi_123' } },
      };

      service['stripe'] = {
        webhooks: {
          constructEvent: jest.fn().mockReturnValue(mockEvent),
        },
      } as any;

      const result = await service.handleWebhookEvent(
        JSON.stringify(mockEvent),
        'signature_123',
      );

      expect(result).toEqual(mockEvent);
    });

    it('should throw BadRequestException on invalid signature', async () => {
      service['stripe'] = {
        webhooks: {
          constructEvent: jest.fn().mockImplementation(() => {
            throw new Error('Invalid signature');
          }),
        },
      } as any;

      await expect(
        service.handleWebhookEvent('{}', 'invalid_signature'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if Stripe is not configured', async () => {
      service['stripe'] = null as any;

      await expect(
        service.handleWebhookEvent('{}', 'signature'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('retrievePaymentIntent', () => {
    it('should retrieve a payment intent by ID', async () => {
      const mockPaymentIntent = {
        id: 'pi_123',
        status: 'succeeded',
        amount: 10000,
      };

      service['stripe'] = {
        paymentIntents: {
          retrieve: jest.fn().mockResolvedValue(mockPaymentIntent),
        },
      } as any;

      const result = await service.retrievePaymentIntent('pi_123');

      expect(result).toEqual(mockPaymentIntent);
    });

    it('should throw BadRequestException on retrieve error', async () => {
      service['stripe'] = {
        paymentIntents: {
          retrieve: jest.fn().mockRejectedValue(new Error('Not found')),
        },
      } as any;

      await expect(
        service.retrievePaymentIntent('pi_nonexistent'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('parseWebhookEvent', () => {
    it('should parse JSON webhook event', () => {
      const mockEvent = {
        id: 'evt_123',
        type: 'payment_intent.succeeded',
      };

      service['stripe'] = {} as any;

      const result = service.parseWebhookEvent(JSON.stringify(mockEvent));

      expect(result).toEqual(mockEvent);
    });

    it('should throw BadRequestException if Stripe is not configured', () => {
      service['stripe'] = null as any;

      expect(() => {
        service.parseWebhookEvent('{}');
      }).toThrow(BadRequestException);
    });
  });
});
