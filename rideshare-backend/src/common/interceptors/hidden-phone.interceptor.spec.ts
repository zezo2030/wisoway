import { scrubHiddenPhones } from './hidden-phone.interceptor';

describe('scrubHiddenPhones', () => {
  const user = (id: string, hide: boolean) => ({
    id,
    name: id,
    phoneNumber: `+96279000000${id.length}`,
    hidePhoneNumber: hide,
  });

  it("blanks another user's hidden phone, however deep it sits", () => {
    const data = {
      data: [
        {
          id: 'b1',
          user: user('passenger', true),
          trip: { driver: user('driver', false) },
        },
      ],
    };
    scrubHiddenPhones(data, 'driver');
    expect(data.data[0].user.phoneNumber).toBeNull();
    expect(data.data[0].trip.driver.phoneNumber).not.toBeNull();
  });

  it('leaves your own phone alone', () => {
    const me = user('me', true);
    scrubHiddenPhones({ user: me }, 'me');
    expect(me.phoneNumber).not.toBeNull();
  });

  it('leaves users who did not hide their phone alone', () => {
    const other = user('other', false);
    scrubHiddenPhones([other], 'me');
    expect(other.phoneNumber).not.toBeNull();
  });

  it('survives cycles and dates', () => {
    const a: any = {
      id: 'a',
      hidePhoneNumber: true,
      phoneNumber: '1',
      at: new Date(),
    };
    a.self = a;
    expect(() => scrubHiddenPhones(a, null)).not.toThrow();
    expect(a.phoneNumber).toBeNull();
  });
});
