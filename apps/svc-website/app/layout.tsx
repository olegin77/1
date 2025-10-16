import "./globals.css";
import type { Metadata } from "next";
import { ReactNode } from "react";
import Providers from "./providers";
import { inter, playfair } from "../lib/fonts";
import { getMessages } from "../lib/messages";

export const metadata: Metadata = {
  title: "WeddingTech — Couple Website",
  description:
    "Personalised wedding microsites for couples planning their WeddingTech celebration.",
  metadataBase: new URL(process.env.APP_BASE_URL ?? "https://weddingtech.uz"),
  openGraph: {
    title: "WeddingTech — Couple Website",
    description:
      "Share your story, collect RSVPs, and keep guests informed via WeddingTech.",
    type: "website"
  }
};

type LayoutProps = {
  children: ReactNode;
  params: { locale?: string };
};

export default function RootLayout({ children, params }: LayoutProps) {
  const locale = params?.locale ?? "ru";
  const messages = getMessages(locale);

  return (
    <html lang={locale} className={playfair.variable}>
      <body className={inter.className}>
        <Providers locale={locale} messages={messages}>
          {children}
        </Providers>
      </body>
    </html>
  );
}
