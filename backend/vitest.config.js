import { defineConfig } from 'vitest/config';

// Phase 4.8 — see tests/setup.js for the globalSetup story. Centralising
// the config in vitest.config.js lets `npm test` and `npm run test:watch`
// share the same isolated test DB.
//
// Phase 4.15 follow-up — `fileParallelism: false`. The Phase 4.13
// boot_seeder.test.js disables the canonical `superadmin` user
// mid-test (then restores in `finally`); other test files race on
// `superadmin` login and fail intermittently with 401 when their
// `beforeAll` happens to land in that window. Serializing files
// eliminates the race. Cost: full suite goes from ~4s to ~10s.
// Tests within a single file are unaffected.
export default defineConfig({
  test: {
    globalSetup: './tests/setup.js',
    include: ['tests/**/*.test.js'],
    fileParallelism: false,
  },
});
