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
  title: "Calligro Academy | Master the Art of Arabic Calligraphy",
  description: "Enroll in world-class calligraphy courses, join live sessions, and master the ancient art with modern experts.",
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
