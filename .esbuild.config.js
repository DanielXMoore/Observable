const esbuild = require('esbuild');

const watch = process.argv.includes('--watch');
const minify = false //!watch || process.argv.includes('--minify');

esbuild.build({
  entryPoints: ['source/main.ts'],
  tsconfig: "./tsconfig.json",
  bundle: true,
  external: ['vscode'],
  format: "cjs",
  sourcemap: true,
  minify,
  watch,
  platform: 'browser',
  outfile: 'dist/main.js',
}).catch(() => process.exit(1))
