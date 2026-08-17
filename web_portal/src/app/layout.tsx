import type { Metadata } from "next";
import { Inter, Outfit, Playfair_Display, Aref_Ruqaa, Amiri, Marhey } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const outfit = Outfit({ subsets: ["latin"], variable: "--font-outfit" });
const playfair = Playfair_Display({ subsets: ["latin"], variable: "--font-playfair" });
const arefRuqaa = Aref_Ruqaa({ weight: ["400", "700"], subsets: ["arabic"], variable: "--font-aref-ruqaa" });
const amiri = Amiri({ weight: ["400", "700"], subsets: ["arabic"], variable: "--font-amiri" });
const marhey = Marhey({ weight: ["300", "400", "500", "600", "700"], subsets: ["arabic"], variable: "--font-marhey" });

export const metadata: Metadata = {
  metadataBase: new URL('https://calligroacademy.com'),
  title: {
    default: "Calligro Academy | Master the Art of Arabic Calligraphy",
    template: "%s | Calligro Academy",
  },
  description: "Enroll in world-class calligraphy courses with global master teachers. Master the ancient art today and get a 50% discount on all courses!",
  openGraph: {
    title: "Calligro Academy | Master the Art of Arabic Calligraphy",
    description: "Enroll in world-class calligraphy courses with global master teachers. Master the ancient art today and get a 50% discount on all courses!",
    url: "https://calligroacademy.com",
    siteName: "Calligro Academy",
    images: [
      {
        url: "/assets/images/Logo.png",
        width: 800,
        height: 600,
        alt: "Calligro Academy Logo",
      },
    ],
    locale: "en_US",
    alternateLocale: "ar_AR",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Calligro Academy | Master the Art of Arabic Calligraphy",
    description: "Enroll in world-class calligraphy courses with global master teachers. Master the ancient art today and get a 50% discount on all courses!",
    images: ["/assets/images/Logo.png"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: "/assets/images/Logo.png",
    shortcut: "/assets/images/Logo.png",
    apple: "/assets/images/Logo.png",
  },
};

import { LocaleProvider } from "@/context/LocaleContext";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${inter.variable} ${outfit.variable} ${playfair.variable} ${arefRuqaa.variable} ${amiri.variable} ${marhey.variable} font-sans antialiased`}>
        <LocaleProvider>
          {children}
        </LocaleProvider>
      </body>
    </html>
  );
}
