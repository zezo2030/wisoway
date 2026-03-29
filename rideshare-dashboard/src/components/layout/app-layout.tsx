import { Outlet } from "react-router-dom"
import { Sidebar } from "./sidebar"
import { Header } from "./header"
import { useLanguage } from "@/providers/language-provider"

export function AppLayout() {
  const { dir } = useLanguage()

  return (
    <div className="flex min-h-screen bg-background text-foreground" dir={dir}>
      {/* Desktop Sidebar */}
      <div className="hidden lg:flex sticky top-0 h-screen">
        <Sidebar className="h-full" />
      </div>

      {/* Main Content Area */}
      <div className="flex flex-col flex-1 min-w-0">
        <Header />
        <main className="flex-1 p-4 lg:p-6 bg-muted/10">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
