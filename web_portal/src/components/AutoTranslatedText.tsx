"use client";
import React, { useState, useEffect } from "react";
import { useLocale } from "@/context/LocaleContext";
import { translateText } from "@/lib/actions/translator";
import { motion, AnimatePresence } from "framer-motion";

interface AutoTranslatedTextProps {
  text: string;
  className?: string;
}

export default function AutoTranslatedText({ text, className }: AutoTranslatedTextProps) {
  const { locale } = useLocale();
  const [displayText, setDisplayText] = useState(text);
  const [isTranslating, setIsTranslating] = useState(false);
  const [lastProcessed, setLastProcessed] = useState({ text: "", locale: "" });

  useEffect(() => {
    // Prevent duplicate translation calls
    if (text === lastProcessed.text && locale === lastProcessed.locale) return;

    // Reset if text is simple or empty
    if (!text || text === "Untitled" || text === "Untitled Course") {
      setDisplayText(text);
      return;
    }

    const handleTranslation = async () => {
      setIsTranslating(true);
      setLastProcessed({ text, locale });
      
      try {
        const translated = await translateText(text, locale);
        setDisplayText(translated);
      } catch (error) {
        console.error("Translation error component:", error);
        setDisplayText(text);
      } finally {
        setIsTranslating(false);
      }
    };

    handleTranslation();
  }, [text, locale, lastProcessed]);

  return (
    <AnimatePresence mode="wait">
      <motion.span
        key={`${displayText}-${isTranslating}`}
        initial={{ opacity: 0 }}
        animate={{ opacity: isTranslating ? 0.3 : 1 }}
        exit={{ opacity: 0 }}
        transition={{ duration: 0.3 }}
        className={className}
      >
        {displayText}
      </motion.span>
    </AnimatePresence>
  );
}
