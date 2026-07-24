import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'jsdom',
    include: ['site/src/**/*.test.{ts,tsx}'],
    exclude: ['node_modules/**', 'dist/**', '.build/**', 'releases/**'],
  },
})
