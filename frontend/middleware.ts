import { NextRequest, NextResponse } from 'next/server';
import { locales, defaultLocale, isSupportedLocale } from './lib/i18n';

// Путь уже содержит локаль?
function hasLocale(pathname: string) {
  const seg = pathname.split('/').filter(Boolean)[0];
  return !!seg && isSupportedLocale(seg);
}

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Пропускаем служебные пути
  if (
    pathname.startsWith('/api') ||
    pathname.startsWith('/_next') ||
    pathname.startsWith('/favicon') ||
    pathname.match(/\.(.*)$/)
  ) {
    return NextResponse.next();
  }

  if (!hasLocale(pathname)) {
    // Попробуем из cookie, заголовка или дефолт
    const cookieLocale = req.cookies.get('locale')?.value;
    const header = req.headers.get('accept-language') || '';
    const headerLocale = header.split(',')[0]?.split('-')[0];
    const target =
      (cookieLocale && isSupportedLocale(cookieLocale) && cookieLocale) ||
      (headerLocale && isSupportedLocale(headerLocale) && headerLocale) ||
      defaultLocale;

    const url = req.nextUrl.clone();
    url.pathname = `/${target}${pathname}`;
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

// Применяем ко всем путям
export const config = {
  matcher: ['/((?!_next|.*\\..*|api).*)']
};
