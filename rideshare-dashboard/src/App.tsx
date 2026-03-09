// App: Root component with all providers
// T013: Wires up AuthProvider, QueryProvider, and Router

import { BrowserRouter } from "react-router-dom"
import { AuthProvider } from "@/providers/auth-provider"
import { QueryProvider } from "@/providers/query-provider"
import { AppRoutes } from "@/routes"
import { Toaster } from "@/components/ui/sonner"

function App() {
  return (
    <BrowserRouter>
      <QueryProvider>
        <AuthProvider>
          <AppRoutes />
          <Toaster />
        </AuthProvider>
      </QueryProvider>
    </BrowserRouter>
  )
}

export default App
