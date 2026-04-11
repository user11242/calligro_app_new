import type { Metadata } from "next";
import { Inter, Outfit } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const outfit = Outfit({ subsets: ["latin"], variable: "--font-outfit" });

export const metadata: Metadata = {
  title: "Calligro Academy | Master the Art of Arabic Calligraphy",
  description: "Enroll in world-class calligraphy courses, join live sessions, and master the ancient art with modern experts.",
  icons: {
    icon: "/assets/images/Logo.png",
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
      <body className={`${inter.variable} ${outfit.variable} font-sans antialiased`}>
        <LocaleProvider>
          {children}
        </LocaleProvider>
      </body>
    </html>
  );
}
