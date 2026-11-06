import { applyDecorators } from '@nestjs/common';
import { Transform } from 'class-transformer';
import { IsEmail, MaxLength } from 'class-validator';

/** A valid email, stored trimmed and lower-cased so duplicates can't hide. */
export function NormalizedEmail(): PropertyDecorator {
  return applyDecorators(
    Transform(({ value }: { value: unknown }) =>
      typeof value === 'string' ? value.trim().toLowerCase() : value,
    ),
    IsEmail({}, { message: 'Email must be a valid email address' }),
    MaxLength(254),
  );
}
