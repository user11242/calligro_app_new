import { useLocale } from "@/shared/i18n/LocaleContext";
import en from "@/shared/i18n/locales/en.json";
import ar from "@/shared/i18n/locales/ar.json";
import tr from "@/shared/i18n/locales/tr.json";

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
  const language: Language = (translations[locale as Language]) ? (locale as Language) : "en";
  const dict = translations[language];

  // The 't' function takes a translation key and returns the translated string
  const t = (key: string): string => {
    return (dict as any)[key] || key;
  };

  return { t, locale: language };
}
