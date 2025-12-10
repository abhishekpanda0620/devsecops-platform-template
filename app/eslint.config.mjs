import js from "@eslint/js";
import globals from "globals";
import { defineConfig } from "eslint/config";

export default defineConfig([
  // Source files - Node.js environment
  {
    files: ["src/**/*.{js,mjs,cjs}"],
    plugins: { js },
    extends: ["js/recommended"],
    languageOptions: {
      globals: {
        ...globals.node,
      },
    },
    rules: {
      "no-unused-vars": ["error", { "argsIgnorePattern": "^_|^next$" }],
    },
  },
  // Test files - Node.js + Jest environment
  {
    files: ["tests/**/*.{js,mjs,cjs}"],
    plugins: { js },
    extends: ["js/recommended"],
    languageOptions: {
      globals: {
        ...globals.node,
        ...globals.jest,
      },
    },
  },
]);
