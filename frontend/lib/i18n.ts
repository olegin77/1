export const locales = (process.env.APP_LOCALES ?? 'ru').split(',').map(s => s.trim()).filter(Boolean);
export const defaultLocale = (process.env.APP_DEFAULT_LOCALE ?? locales[0] ?? 'ru').trim();

export function isSupportedLocale(l: string) {
  return locales.includes(l);
}
