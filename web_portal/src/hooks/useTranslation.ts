import { useLocale } from "@/context/LocaleContext";
import en from "@/locales/en.json";
import ar from "@/locales/ar.json";
import tr from "@/locales/tr.json";

const translations = {
  en,
  ar,
  tr,
};

type Language = keyof typeof translations;
type TranslationKey = keyof typeof en;

export function useTranslation() {
  const { locale } = useLocale();

  // If the locale is invalid, default to english
  const language: Language = locale === "ar" ? "ar" : "en";
  const dict = translations[language];

  // The 't' function takes a translation key and returns the translated string
  const t = (key: string): string => {
    return (dict as any)[key] || key;
  };

  return { t, locale: language };
}
