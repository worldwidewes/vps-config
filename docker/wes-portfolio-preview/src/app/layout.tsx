import type { Metadata } from "next";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import "./globals.css";

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://weschance.com";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  alternates: { canonical: "/" },
  title: { default: "Wes — Mission Systems", template: "%s — Wes" },
  description: "Independent technical builder exploring useful systems where AI, software, and real-world hardware meet.",
  openGraph: { type: "website", title: "Wes — Mission Systems", description: "Local AI, browser agents, self-hosted tools, and practical systems work.", images: [{ url: "/opengraph-image.svg", width: 1200, height: 630, alt: "Wes — Mission Systems" }] },
  twitter: { card: "summary_large_image", title: "Wes — Mission Systems", description: "Useful systems where AI, software, and hardware meet." },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body id="top"><a className="skip-link" href="#main-content">Skip to content</a><Header />{children}<Footer /></body></html>;
}
