import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { RegisterDriverDto } from './register-driver.dto';

const validPayload = {
  registrationToken: 'tok',
  name: 'Driver',
  password: 'Password1',
  vehicleType: 'sedan',
  plateNumber: 'ABC123',
  model: 'Camry',
  carImageUrl: 'https://cdn/car.jpg',
  insuranceImageUrl: 'https://cdn/ins.jpg',
};

describe('RegisterDriverDto', () => {
  it('accepts a payload with an insurance image', async () => {
    const errors = await validate(
      plainToInstance(RegisterDriverDto, validPayload),
    );
    expect(errors).toHaveLength(0);
  });

  it('rejects register payload without insuranceImageUrl', async () => {
    const { insuranceImageUrl: _omitted, ...payload } = validPayload;
    const errors = await validate(plainToInstance(RegisterDriverDto, payload));
    expect(errors.some((e) => e.property === 'insuranceImageUrl')).toBe(true);
  });
});
