function normalizeLocale(input?: string | null) {
  return (input ?? "").trim().toLowerCase();
}

const localeCandidates = (process.env.APP_LOCALES ?? "ru")
  .split(",")
  .map(normalizeLocale)
  .filter(Boolean);

if (localeCandidates.length === 0) {
  localeCandidates.push("ru");
}

const localeSet = new Set(localeCandidates);

export const locales = Array.from(localeSet);

const envDefault = normalizeLocale(process.env.APP_DEFAULT_LOCALE);
export const defaultLocale =
  envDefault && localeSet.has(envDefault) ? envDefault : locales[0];

function matchLocale(candidate?: string | null) {
  const normalized = normalizeLocale(candidate);
  if (!normalized) {
    return null;
  }

  if (localeSet.has(normalized)) {
    return normalized;
  }

  const short = normalized.split("-")[0];
  if (short && localeSet.has(short)) {
    return short;
  }

  return null;
}

export function resolveLocale(
  ...candidates: Array<string | null | undefined>
) {
  for (const candidate of candidates) {
    const match = matchLocale(candidate);
    if (match) {
      return match;
    }
  }

  return defaultLocale;
}

export function isSupportedLocale(locale: string | null | undefined) {
  return localeSet.has(normalizeLocale(locale));
}
