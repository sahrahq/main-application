import { LoggingPushDelivery } from './logging-push.delivery';

/**
 * The stub push delivery must be UNABLE to run in production.
 *
 * Weaker consequence than the OTP stub — a push in a log is not a working
 * credential — but a worse silence. Every diner whose table was cancelled
 * would simply never be told, while the system recorded `sent_at` and reported
 * success. "We forgot to swap the adapter" is exactly the failure NOTIFY-1 was
 * opened about.
 */
describe('LoggingPushDelivery refuses production', () => {
  const original = process.env.NODE_ENV;
  afterEach(() => {
    process.env.NODE_ENV = original;
  });

  it('throws when constructed with NODE_ENV=production', () => {
    expect(() => new LoggingPushDelivery('production')).toThrow(/never run in production/i);
  });

  it('reads NODE_ENV from the environment, not only from the argument', () => {
    // The DI factory calls `new LoggingPushDelivery()` with no argument, so a
    // guard that only checked its parameter would never fire where it counts.
    process.env.NODE_ENV = 'production';
    expect(() => new LoggingPushDelivery()).toThrow(/never run in production/i);
  });

  it('constructs in development and in test', () => {
    expect(() => new LoggingPushDelivery('development')).not.toThrow();
    expect(() => new LoggingPushDelivery('test')).not.toThrow();
  });
});
