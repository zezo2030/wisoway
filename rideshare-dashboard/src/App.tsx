// App: Root component with all providers
// T013: Wires up AuthProvider, QueryProvider, Router, and LanguageProvider

import { BrowserRouter } from "react-router-dom"
import { AuthProvider } from "@/providers/auth-provider"
import { QueryProvider } from "@/providers/query-provider"
import { LanguageProvider } from "@/providers/language-provider"
import { AppRoutes } from "@/routes"
import { Toaster } from "@/components/ui/sonner"

function App() {
  return (
    <BrowserRouter>
      <QueryProvider>
        <LanguageProvider>
          <AuthProvider>
            <AppRoutes />
            <Toaster />
          </AuthProvider>
        </LanguageProvider>
      </QueryProvider>
    </BrowserRouter>
  )
}

export default App
