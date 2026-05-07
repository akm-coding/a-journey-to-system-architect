// eslint.config.js -- ESLint v9 "flat config" format
// This replaces the legacy .eslintrc.* files. Flat config uses plain arrays of config objects.
import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import eslintConfigPrettier from 'eslint-config-prettier';

export default [
  // Apply recommended JavaScript rules (no-undef, no-unused-vars, etc.)
  js.configs.recommended,

  // Apply recommended TypeScript rules (overrides JS rules where needed)
  ...tseslint.configs.recommended,

  // Ignore build output and dependencies
  {
    ignores: ['dist/', 'node_modules/'],
  },

  // Project-specific rules for TypeScript/TSX files
  {
    files: ['src/**/*.ts', 'src/**/*.tsx'],
    rules: {
      // Allow unused variables prefixed with _ (common pattern for ignored params)
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },

  // Disable formatting rules that conflict with Prettier (must be last)
  eslintConfigPrettier,
];
