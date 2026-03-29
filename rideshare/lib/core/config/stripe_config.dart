/// Pass at build time: `--dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...`
const String kStripePublishableKey = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue: '',
);
