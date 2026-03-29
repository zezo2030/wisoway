// LanguageContext: React Context for i18n language switching
// Provides language state, direction (ltr/rtl), and t() translation helper

import { createContext, useContext, useEffect, useState } from "react"
import { type Language, type TranslationKey, translations } from "@/i18n/translations"

interface LanguageContextType {
  language: Language
  dir: "ltr" | "rtl"
  setLanguage: (lang: Language) => void
  t: (key: TranslationKey) => string
  toggleLanguage: () => void
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined)

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [language, setLanguageState] = useState<Language>(() => {
    return (localStorage.getItem("dashboard-lang") as Language) || "en"
  })

  const dir = language === "ar" ? "rtl" : "ltr"

  useEffect(() => {
    localStorage.setItem("dashboard-lang", language)
    document.documentElement.lang = language
    document.documentElement.dir = dir
  }, [language, dir])

  const setLanguage = (lang: Language) => {
    setLanguageState(lang)
  }

  const toggleLanguage = () => {
    setLanguageState((prev) => (prev === "en" ? "ar" : "en"))
  }

  const t = (key: TranslationKey): string => {
    return translations[language][key] ?? translations["en"][key] ?? key
  }

  return (
    <LanguageContext.Provider value={{ language, dir, setLanguage, t, toggleLanguage }}>
      {children}
    </LanguageContext.Provider>
  )
}

export function useLanguage() {
  const ctx = useContext(LanguageContext)
  if (!ctx) throw new Error("useLanguage must be used within LanguageProvider")
  return ctx
}
