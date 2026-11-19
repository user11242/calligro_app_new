"use client";
import React, { createContext, useContext, useState, useEffect, ReactNode } from "react";

type Locale = "en" | "ar" | "tr";

interface LocaleContextType {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  isRTL: boolean;
}

const LocaleContext = createContext<LocaleContextType | undefined>(undefined);

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("en");

  // Load saved language or default to browser language
  useEffect(() => {
    const saved = localStorage.getItem("calligro_locale") as Locale;
    if (saved && ["en", "ar", "tr"].includes(saved)) {
      setLocaleState(saved);
    } else {
      const browserLang = navigator.language.split("-")[0];
      if (["en", "ar", "tr"].includes(browserLang)) {
        setLocaleState(browserLang as Locale);
      }
    }
  }, []);

  const setLocale = (newLocale: Locale) => {
    setLocaleState(newLocale);
    localStorage.setItem("calligro_locale", newLocale);
    document.documentElement.dir = newLocale === "ar" ? "rtl" : "ltr";
    document.documentElement.lang = newLocale;
  };

  useEffect(() => {
    document.documentElement.dir = locale === "ar" ? "rtl" : "ltr";
    document.documentElement.lang = locale;
  }, [locale]);

  const isRTL = locale === "ar";

  return (
    <LocaleContext.Provider value={{ locale, setLocale, isRTL }}>
      {children}
    </LocaleContext.Provider>
  );
}

export function useLocale() {
  const context = useContext(LocaleContext);
  if (context === undefined) {
    throw new Error("useLocale must be used within a LocaleProvider");
  }
  return context;
}
