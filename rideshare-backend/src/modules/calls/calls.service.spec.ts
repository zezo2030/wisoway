import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { CallsService } from './calls.service';
import { BookingEntity } from '../../database/entities/booking.entity';
import { CallSessionEntity } from '../../database/entities/call-session.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { ProxyPoolService } from './proxy-pool.service';

describe('CallsService', () => {
  let service: CallsService;
  let bookingRepo: any;
  let callSessionRepo: any;
  let userRepo: any;
  let proxyPoolService: any;

  const mockBookingRepo = {
    findOne: jest.fn(),
  };
  const mockCallSessionRepo = {
    save: jest.fn(),
    create: jest.fn((dto) => dto),
    findOne: jest.fn(),
  };
  const mockUserRepo = {
    findOne: jest.fn(),
  };
  const mockProxyPoolService = {
    allocate: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CallsService,
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: mockBookingRepo,
        },
        {
          provide: getRepositoryToken(CallSessionEntity),
          useValue: mockCallSessionRepo,
        },
        { provide: getRepositoryToken(UserEntity), useValue: mockUserRepo },
        { provide: ProxyPoolService, useValue: mockProxyPoolService },
      ],
    }).compile();

    service = module.get<CallsService>(CallsService);
    bookingRepo = module.get(getRepositoryToken(BookingEntity));
    callSessionRepo = module.get(getRepositoryToken(CallSessionEntity));
    userRepo = module.get(getRepositoryToken(UserEntity));
    proxyPoolService = module.get<ProxyPoolService>(ProxyPoolService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('allows a call on a confirmed booking that was never paid for', async () => {
    bookingRepo.findOne.mockResolvedValue({
      id: 'b-1',
      userId: 'rider-1',
      hasDriverPaidToContact: false,
      trip: { driverId: 'driver-1' },
    });
    userRepo.findOne
      .mockResolvedValueOnce({ id: 'driver-1', phoneNumber: '+962700000001' })
      .mockResolvedValueOnce({
        id: 'rider-1',
        phoneNumber: '+962700000002',
        hidePhoneNumber: false,
      });
    proxyPoolService.allocate.mockResolvedValue('+962790000001');
    callSessionRepo.save.mockResolvedValue({
      id: 'session-1',
      createdAt: new Date(),
    });

    const result = await service.initiate('b-1', 'driver-1');

    expect(result).toBeDefined();
    expect(result.callSessionId).toBe('session-1');
    expect(result.proxyNumberE164).toBe('+962790000001');
  });

  it('throws NotFoundException when the booking does not exist', async () => {
    bookingRepo.findOne.mockResolvedValue(null);

    await expect(service.initiate('missing', 'driver-1')).rejects.toThrow(
      NotFoundException,
    );
  });

  it('throws ForbiddenException when the caller is not a participant', async () => {
    bookingRepo.findOne.mockResolvedValue({
      id: 'b-1',
      userId: 'rider-1',
      hasDriverPaidToContact: false,
      trip: { driverId: 'driver-1' },
    });

    await expect(service.initiate('b-1', 'stranger')).rejects.toThrow(
      ForbiddenException,
    );
  });
});
