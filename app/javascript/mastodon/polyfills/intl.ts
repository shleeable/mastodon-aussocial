import { shouldPolyfill as shoudPolyfillPluralRules } from '@formatjs/intl-pluralrules/should-polyfill.js';

async function loadIntlPluralRulesPolyfills(locale: string) {
  const unsupportedLocale = shoudPolyfillPluralRules(locale);
  // This locale is supported
  if (!unsupportedLocale) {
    return;
  }
  // Load the polyfill 1st BEFORE loading data
  await import('@formatjs/intl-pluralrules/polyfill-force.js');
  await import(
    `../../../../node_modules/@formatjs/intl-pluralrules/locale-data/${unsupportedLocale}.js`
  );
}

export async function loadIntlPolyfills() {
  // eslint-disable-next-line @typescript-eslint/prefer-nullish-coalescing -- we want to match empty strings
  const locale = document.querySelector('html')?.lang || 'en';

  // Supported from Safari 13+, may still be useful
  await loadIntlPluralRulesPolyfills(locale);
}
