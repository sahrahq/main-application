import { LoggingOtpDelivery } from './logging-otp.delivery';
import { otpProviders } from '../otp.providers';
import { OTP_DELIVERY } from '../otp.ports';

/**
 * The stub OTP delivery must be UNABLE to run in production.
 *
 * It writes live one-time codes to the application log. In production that
 * puts a working credential into log aggregation, where it is retained,
 * indexed, and readable by anyone with dashboard access — a complete
 * authentication bypass for every account that requests a code.
 *
 * The class refuses to construct when `NODE_ENV=production`, which is the
 * strongest available guard: the failure is at BOOT, not at the first OTP, so
 * "we forgot to swap the adapter" cannot be discovered by a user.
 *
 * Nothing asserted this until now. The guard existed and had never been
 * watched to fire — which, per the four-instance table in
 * ENGINEERING-STANDARDS, is not the same as knowing it works.
 */
describe('LoggingOtpDelivery refuses production', () => {
  const original = process.env.NODE_ENV;
  afterEach(() => {
    process.env.NODE_ENV = original;
  });

  it('throws when constructed with NODE_ENV=production', () => {
    expect(() => new LoggingOtpDelivery('production')).toThrow(
      /must never run in production/i,
    );
  });

  it('reads NODE_ENV from the environment, not only from the argument', () => {
    // The DI factory calls `new LoggingOtpDelivery()` with no argument, so a
    // guard that only checked its parameter would never fire in the one place
    // that matters.
    process.env.NODE_ENV = 'production';
    expect(() => new LoggingOtpDelivery()).toThrow(/must never run in production/i);
  });

  it('constructs in development and in test', () => {
    expect(() => new LoggingOtpDelivery('development')).not.toThrow();
    expect(() => new LoggingOtpDelivery('test')).not.toThrow();
  });

  it('is what the OTP_DELIVERY provider actually builds', () => {
    // The guard is worthless if the container binds something else. Resolve
    // the real factory rather than trusting the import.
    const provider = otpProviders.find(
      (p) => typeof p === 'object' && 'provide' in p && p.provide === OTP_DELIVERY,
    );
    expect(provider).toBeDefined();

    const factory = (provider as { useFactory: () => unknown }).useFactory;
    expect(factory()).toBeInstanceOf(LoggingOtpDelivery);

    // …and therefore the whole container refuses to build in production.
    process.env.NODE_ENV = 'production';
    expect(() => factory()).toThrow(/must never run in production/i);
  });

  it('logs the code in development — which is exactly why it is banned above', () => {
    const delivery = new LoggingOtpDelivery('development');
    expect(delivery.channel).toBe('log');
  });
});
