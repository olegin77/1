/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    typedRoutes: true
  },
  i18n: {
    locales: ["ru", "uz"],
    defaultLocale: "ru",
    localeDetection: true
  }
};

export default nextConfig;
