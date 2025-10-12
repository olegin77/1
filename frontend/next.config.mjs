/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  typedRoutes: true,
  i18n: {
    locales: ["ru", "uz"],
    defaultLocale: "ru",
    localeDetection: false
  }
};

export default nextConfig;
