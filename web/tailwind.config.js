/** @type {import('tailwindcss').Config} */
const contentGlobs = [
  './templates/**/*.tmpl',
  './cmd/**/*.{go,tmpl,html}',
  './internal/**/*.{go,tmpl,html}',
  './content/**/*.{md,html}',
  './public/**/*.html',
];

const safelistPatterns = [
  /(?:bg|text|border|ring)-(?:emerald|amber|orange|rose|sky|slate|indigo|violet|cyan|purple|fuchsia|teal|pink)-(?:50|100|200|300|400|500|600|700|800|900)/,
  /(?:bg|text|border|ring)-(?:gray|stone|neutral|zinc)-(?:50|100|200|300|400|500|600|700|800|900)/,
  /(?:bg|text|border|ring)-(?:white|black)/,
  /bg-gradient-to-(?:br|r|l|b|t)/,
  /(?:from|via|to)-(?:emerald|amber|orange|rose|sky|slate|indigo|violet|cyan|purple|fuchsia|teal|pink)-(?:100|200|300|400|500|600|700|800|900)/,
  /(?:ring|border|bg)-white\/(?:30|40|45|50|60|70|80|90)/,
];

module.exports = {
  content: contentGlobs,
  safelist: safelistPatterns,
  future: {
    hoverOnlyWhenSupported: true,
  },
  theme: {
    extend: {},
  },
  plugins: [],
};
