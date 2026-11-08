import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { RegisterDriverDto } from './register-driver.dto';

const validPayload = {
  registrationToken: 'tok',
  name: 'Driver',
  email: 'driver@example.com',
  password: 'Password1',
  vehicleType: 'sedan',
  plateNumber: 'ABC123',
  model: 'Camry',
  color: 'white',
  carImageUrl: 'https://cdn/car.jpg',
  insuranceImageUrl: 'https://cdn/ins.jpg',
  nationalIdImageUrl: 'https://cdn/id.jpg',
};

describe('RegisterDriverDto', () => {
  it('accepts a payload with an insurance image', async () => {
    const errors = await validate(
      plainToInstance(RegisterDriverDto, validPayload),
    );
    expect(errors).toHaveLength(0);
  });

  it('rejects a payload without an email', async () => {
    const { email: _omitted, ...payload } = validPayload;
    const errors = await validate(plainToInstance(RegisterDriverDto, payload));
    expect(errors.some((e) => e.property === 'email')).toBe(true);
  });

  it('rejects a malformed email', async () => {
    const errors = await validate(
      plainToInstance(RegisterDriverDto, { ...validPayload, email: 'nope' }),
    );
    expect(errors.some((e) => e.property === 'email')).toBe(true);
  });

  it('stores the email trimmed and in lower case', () => {
    const dto = plainToInstance(RegisterDriverDto, {
      ...validPayload,
      email: ' Driver@Example.COM ',
    });
    expect(dto.email).toBe('driver@example.com');
  });

  it('rejects register payload without insuranceImageUrl', async () => {
    const { insuranceImageUrl: _omitted, ...payload } = validPayload;
    const errors = await validate(plainToInstance(RegisterDriverDto, payload));
    expect(errors.some((e) => e.property === 'insuranceImageUrl')).toBe(true);
  });

  it.each([undefined, '', '   '])(
    'rejects a registration without the car colour (%p)',
    async (color) => {
      const errors = await validate(
        plainToInstance(RegisterDriverDto, { ...validPayload, color }),
      );
      expect(errors.some((e) => e.property === 'color')).toBe(true);
    },
  );

  it('rejects register payload without nationalIdImageUrl', async () => {
    const { nationalIdImageUrl: _omitted, ...payload } = validPayload;
    const errors = await validate(plainToInstance(RegisterDriverDto, payload));
    expect(errors.some((e) => e.property === 'nationalIdImageUrl')).toBe(true);
  });
});
