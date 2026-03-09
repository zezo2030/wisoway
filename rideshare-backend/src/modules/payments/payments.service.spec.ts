import { Test, TestingModule } from '@nestjs/testing';
import { getModelToken } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { PaymentsService } from './payments.service';
import { StripeService } from './stripe.service';
import { A2aCliqService } from './a2a-cliq.service';
import { Payment, PaymentDocument } from './schemas/payment.schema';
import {
  CommunicationFee,
  CommunicationFeeDocument,
} from './schemas/communication-fee.schema';
import { Booking, BookingDocument } from '../bookings/schemas/booking.schema';
import { Trip, TripDocument } from '../trips/schemas/trip.schema';
import { User, UserDocument } from '../users/schemas/user.schema';
import { NotificationsService } from '../notifications/notifications.service';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';

describe('PaymentsService', () => {
  let service: PaymentsService;
  let paymentModel: Model<PaymentDocument>;
  let communicationFeeModel: Model<CommunicationFeeDocument>;
  let bookingModel: Model<BookingDocument>;
  let tripModel: Model<TripDocument>;
  let userModel: Model<UserDocument>;
  let stripeService: StripeService;
  let a2aCliqService: A2aCliqService;

  const mockPayment = {
    _id: 'payment123',
    tripId: 'trip123',
    bookingId: 'booking123',
    userId: 'user123',
    amount: 100,
    currency: 'EGP',
    method: 'manual',
    status: 'pending',
    paymentType: 'trip',
    proofImageUrl: 'https://example.com/proof.jpg',
    save: jest.fn().mockResolvedValue(this),
  };

  const mockBooking = {
    _id: 'booking123',
    tripId: 'trip123',
    userId: 'user123',
    seatNumber: '0-0',
    status: 'pending',
    hasDriverPaidToContact: false,
    populate: jest.fn().mockReturnThis(),
    exec: jest.fn().mockResolvedValue({
      _id: 'booking123',
      tripId: {
        _id: 'trip123',
        driverId: 'driver123',
        from: { name: 'Cairo' },
        to: { name: 'Alexandria' },
      },
      userId: 'user123',
    }),
    save: jest.fn().mockResolvedValue(this),
  };

  const mockTrip = {
    _id: 'trip123',
    driverId: 'driver123',
    from: { name: 'Cairo' },
    to: { name: 'Alexandria' },
    price: 100,
    currency: 'EGP',
    status: 'active',
    exec: jest.fn().mockResolvedValue({
      _id: 'trip123',
      driverId: 'driver123',
    }),
  };

  const mockCommunicationFee = {
    _id: 'fee123',
    countryCode: 'EG',
    feeAmount: 50,
    currency: 'EGP',
    isActive: true,
  };

  const mockSession = {
    startTransaction: jest.fn(),
    commitTransaction: jest.fn(),
    abortTransaction: jest.fn(),
    endSession: jest.fn(),
  };

  class MockPaymentModel {
    save: jest.Mock;
    constructor(dto: any) {
      Object.assign(this, { ...mockPayment, ...dto });
      this.save = jest.fn().mockResolvedValue(this);
    }
    static find = jest.fn().mockReturnThis();
    static findOne = jest.fn().mockReturnThis();
    static findById = jest.fn().mockReturnThis();
    static create = jest.fn().mockResolvedValue(mockPayment);
    static countDocuments = jest.fn().mockResolvedValue(0);
    static exec = jest.fn().mockResolvedValue(mockPayment);
    static db = {
      startSession: jest.fn().mockResolvedValue(mockSession),
    };
  }

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        {
          provide: getModelToken(Payment.name),
          useValue: MockPaymentModel,
        },
        {
          provide: getModelToken(CommunicationFee.name),
          useValue: {
            findOne: jest.fn().mockReturnThis(),
            exec: jest.fn().mockResolvedValue(mockCommunicationFee),
          },
        },
        {
          provide: getModelToken(Booking.name),
          useValue: {
            findById: jest.fn().mockReturnThis(),
            populate: jest.fn().mockReturnThis(),
            exec: jest.fn().mockResolvedValue(mockBooking),
            save: jest.fn().mockResolvedValue(mockBooking),
          },
        },
        {
          provide: getModelToken(Trip.name),
          useValue: {
            findById: jest.fn().mockReturnThis(),
            exec: jest.fn().mockResolvedValue(mockTrip),
          },
        },
        {
          provide: getModelToken(User.name),
          useValue: {
            findById: jest.fn().mockReturnThis(),
            select: jest.fn().mockReturnThis(),
            exec: jest.fn(),
            updateOne: jest.fn().mockReturnValue({
              exec: jest.fn().mockResolvedValue({ modifiedCount: 1 }),
            }),
          },
        },
        {
          provide: NotificationsService,
          useValue: { create: jest.fn().mockResolvedValue(undefined) },
        },
        {
          provide: StripeService,
          useValue: {
            createPaymentIntent: jest.fn().mockResolvedValue({
              clientSecret: 'secret123',
              paymentIntentId: 'pi123',
            }),
            handleWebhookEvent: jest.fn(),
          },
        },
        {
          provide: A2aCliqService,
          useValue: {
            purchase: jest.fn().mockResolvedValue({
              errorCode: 0,
              description: 'Success',
            }),
            paymentInquiry: jest.fn().mockResolvedValue({
              MessageTrxID: 'CLIQ123',
              StatusCode: '0',
              StatusDescription: 'Success',
            }),
          },
        },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
    paymentModel = module.get<Model<PaymentDocument>>(
      getModelToken(Payment.name),
    );
    communicationFeeModel = module.get<Model<CommunicationFeeDocument>>(
      getModelToken(CommunicationFee.name),
    );
    bookingModel = module.get<Model<BookingDocument>>(
      getModelToken(Booking.name),
    );
    tripModel = module.get<Model<TripDocument>>(getModelToken(Trip.name));
    userModel = module.get<Model<UserDocument>>(getModelToken(User.name));
    stripeService = module.get<StripeService>(StripeService);
    a2aCliqService = module.get<A2aCliqService>(A2aCliqService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createPayment', () => {
    it('should create a payment successfully', async () => {
      const createPaymentDto = {
        tripId: 'trip123',
        bookingId: 'booking123',
        amount: 100,
        currency: 'EGP',
        method: 'manual',
        proofImageUrl: 'https://example.com/proof.jpg',
      };

      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockBooking),
      } as any);

      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      } as any);

      jest.spyOn(paymentModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      const result = await service.createPayment(createPaymentDto, 'user123');
      expect(result).toBeDefined();
    });

    it('should throw NotFoundException if booking not found', async () => {
      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      await expect(
        service.createPayment(
          {
            tripId: 'trip123',
            bookingId: 'nonexistent',
            amount: 100,
            method: 'manual',
          },
          'user123',
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ForbiddenException if user does not own booking', async () => {
      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          ...mockBooking,
          userId: 'otherUser',
        }),
      } as any);

      await expect(
        service.createPayment(
          {
            tripId: 'trip123',
            bookingId: 'booking123',
            amount: 100,
            method: 'manual',
          },
          'user123',
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException if payment already exists', async () => {
      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockBooking),
      } as any);

      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      } as any);

      jest.spyOn(paymentModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockPayment),
      } as any);

      await expect(
        service.createPayment(
          {
            tripId: 'trip123',
            bookingId: 'booking123',
            amount: 100,
            method: 'manual',
          },
          'user123',
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if manual payment has no proof', async () => {
      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockBooking),
      } as any);

      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockTrip),
      } as any);

      jest.spyOn(paymentModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      await expect(
        service.createPayment(
          {
            tripId: 'trip123',
            bookingId: 'booking123',
            amount: 100,
            method: 'manual',
          },
          'user123',
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('createCommunicationFee', () => {
    it('should create communication fee payment successfully', async () => {
      const createDto = {
        bookingId: 'booking123',
        method: 'manual',
        proofImageUrl: 'https://example.com/proof.jpg',
      };

      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: 'booking123',
          tripId: {
            _id: 'trip123',
            driverId: 'driver123',
          },
          userId: 'user123',
        }),
      } as any);

      jest.spyOn(communicationFeeModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockCommunicationFee),
      } as any);

      jest.spyOn(paymentModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      const result = await service.createCommunicationFee(
        createDto,
        'driver123',
      );
      expect(result).toBeDefined();
    });

    it('should throw ForbiddenException if not trip driver', async () => {
      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: 'booking123',
          tripId: {
            _id: 'trip123',
            driverId: 'otherDriver',
          },
        }),
      } as any);

      await expect(
        service.createCommunicationFee(
          {
            bookingId: 'booking123',
            method: 'manual',
            proofImageUrl: 'proof.jpg',
          },
          'driver123',
        ),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('initiateCliqCommunicationFee', () => {
    it('should initiate CliQ communication fee successfully', async () => {
      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: 'booking123',
          tripId: {
            _id: 'trip123',
            driverId: 'driver123',
          },
          userId: 'user123',
        }),
      } as any);

      jest.spyOn(communicationFeeModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockCommunicationFee),
      } as any);

      jest.spyOn(paymentModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      const result = await service.initiateCliqCommunicationFee({
        bookingId: 'booking123',
        driverId: 'driver123',
        aliasType: 'MOBL',
        aliasValue: '0096278xxxxxxx',
      });

      expect(result).toBeDefined();
    });
  });

  describe('approve', () => {
    it('should approve a payment successfully', async () => {
      const mockPaymentDoc = {
        ...mockPayment,
        status: 'pending',
        paymentType: 'trip',
        save: jest
          .fn()
          .mockResolvedValue({ ...mockPayment, status: 'approved' }),
      };

      jest.spyOn(paymentModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockPaymentDoc),
      } as any);

      const result = await service.approve('payment123', 'admin123', {
        adminNote: 'Approved',
      });
      expect(result.status).toBe('approved');
    });

    it('should update booking when approving communication fee', async () => {
      const mockPaymentDoc = {
        ...mockPayment,
        status: 'pending',
        paymentType: 'communication_fee',
        bookingId: 'booking123',
        save: jest
          .fn()
          .mockResolvedValue({ ...mockPayment, status: 'approved' }),
      };

      const mockBookingDoc = {
        _id: 'booking123',
        hasDriverPaidToContact: false,
        save: jest.fn().mockResolvedValue({ hasDriverPaidToContact: true }),
      };

      jest.spyOn(paymentModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockPaymentDoc),
      } as any);

      jest.spyOn(bookingModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockBookingDoc),
      } as any);

      const result = await service.approve('payment123', 'admin123', {});
      expect(mockBookingDoc.hasDriverPaidToContact).toBe(true);
    });

    it('should throw BadRequestException if payment not pending', async () => {
      jest.spyOn(paymentModel, 'findById').mockReturnValue({
        exec: jest
          .fn()
          .mockResolvedValue({ ...mockPayment, status: 'approved' }),
      } as any);

      await expect(
        service.approve('payment123', 'admin123', {}),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('reject', () => {
    it('should reject a payment successfully', async () => {
      const mockPaymentDoc = {
        ...mockPayment,
        status: 'pending',
        save: jest
          .fn()
          .mockResolvedValue({ ...mockPayment, status: 'rejected' }),
      };

      jest.spyOn(paymentModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockPaymentDoc),
      } as any);

      const result = await service.reject('payment123', 'admin123', {
        adminNote: 'Invalid proof',
      });
      expect(result.status).toBe('rejected');
    });

    it('should throw NotFoundException if payment not found', async () => {
      jest.spyOn(paymentModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      await expect(
        service.reject('nonexistent', 'admin123', { adminNote: 'Test' }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('findByUser', () => {
    it('should return paginated user payments', async () => {
      const mockPayments = [mockPayment];

      jest.spyOn(paymentModel, 'find').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        sort: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue(mockPayments),
      } as any);

      jest.spyOn(paymentModel, 'countDocuments').mockReturnValue({
        exec: jest.fn().mockResolvedValue(1),
      } as any);

      const result = await service.findByUser('user123', {
        page: 1,
        limit: 20,
      });
      expect(result.data).toHaveLength(1);
      expect(result.meta.total).toBe(1);
    });
  });

  describe('findById', () => {
    it('should return payment for owner', async () => {
      jest.spyOn(paymentModel, 'findById').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue(mockPayment),
      } as any);

      const result = await service.findById('payment123', 'user123', false);
      expect(result).toBeDefined();
    });

    it('should return payment for admin', async () => {
      jest.spyOn(paymentModel, 'findById').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue(mockPayment),
      } as any);

      const result = await service.findById('payment123', 'otherUser', true);
      expect(result).toBeDefined();
    });

    it('should throw ForbiddenException for non-owner non-admin', async () => {
      jest.spyOn(paymentModel, 'findById').mockReturnValue({
        populate: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue(mockPayment),
      } as any);

      await expect(
        service.findById('payment123', 'otherUser', false),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('createStripePaymentIntent', () => {
    it('should create Stripe payment intent', async () => {
      const result = await service.createStripePaymentIntent(
        100,
        'EGP',
        'booking123',
        'trip',
      );
      expect(result.clientSecret).toBe('secret123');
      expect(result.paymentIntentId).toBe('pi123');
    });
  });

  describe('chargeDriverWalletForTrip', () => {
    it('should return early when trip already has driverWalletChargeApplied', async () => {
      const tripAlreadyCharged = {
        _id: 'trip123',
        driverId: 'driver123',
        driverWalletChargeApplied: true,
        save: jest.fn(),
        exec: jest.fn().mockResolvedValue({
          _id: 'trip123',
          driverId: 'driver123',
          driverWalletChargeApplied: true,
          save: jest.fn(),
        }),
      };
      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(tripAlreadyCharged),
      } as any);

      await service.chargeDriverWalletForTrip('driver123', 'trip123');
      expect(tripAlreadyCharged.save).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException when wallet balance insufficient', async () => {
      const tripNotCharged = {
        _id: 'trip123',
        driverId: 'driver123',
        driverWalletChargeApplied: false,
        save: jest.fn(),
        exec: jest.fn().mockResolvedValue({
          _id: 'trip123',
          driverId: 'driver123',
          driverWalletChargeApplied: false,
          save: jest.fn(),
        }),
      };
      const driverWithLowBalance = {
        walletBalance: 10,
        walletCurrency: 'EGP',
        hasUsedLifetimeFreeTrip: true,
      };
      jest.spyOn(tripModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(tripNotCharged),
      } as any);
      jest.spyOn(userModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue(driverWithLowBalance),
        }),
      } as any);
      jest.spyOn(communicationFeeModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          countryCode: 'EG',
          feeAmount: 50,
          currency: 'EGP',
          isActive: true,
        }),
      } as any);

      await expect(
        service.chargeDriverWalletForTrip('driver123', 'trip123'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('handleStripeWebhook', () => {
    it('should handle payment_intent.succeeded event', async () => {
      const event = {
        type: 'payment_intent.succeeded',
        data: {
          object: {
            id: 'pi123',
            metadata: { bookingId: 'booking123' },
          },
        },
      };

      jest.spyOn(paymentModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          ...mockPayment,
          status: 'pending',
          paymentType: 'trip',
          save: jest
            .fn()
            .mockResolvedValue({ ...mockPayment, status: 'approved' }),
        }),
      } as any);

      await service.handleStripeWebhook(event);
    });

    it('should handle payment_intent.payment_failed event', async () => {
      const event = {
        type: 'payment_intent.payment_failed',
        data: {
          object: {
            id: 'pi123',
          },
        },
      };

      jest.spyOn(paymentModel, 'findOne').mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          ...mockPayment,
          status: 'pending',
          save: jest
            .fn()
            .mockResolvedValue({ ...mockPayment, status: 'rejected' }),
        }),
      } as any);

      await service.handleStripeWebhook(event);
    });
  });
});
