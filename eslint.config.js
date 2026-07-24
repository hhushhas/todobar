import { tanstackConfig } from '@tanstack/eslint-config'

export default [
  {
    ignores: [
      '.build/**',
      'dist/**',
      'node_modules/**',
      'convex/_generated/**',
      'site/src/routeTree.gen.ts',
      'eslint.config.js',
      'prettier.config.js',
    ],
  },
  ...tanstackConfig,
  {
    ignores: [
      '.build/**',
      'dist/**',
      'node_modules/**',
      'convex/_generated/**',
      'site/src/routeTree.gen.ts',
      'eslint.config.js',
      'prettier.config.js',
    ],
  },
]
