// Header: App header with admin name, logout, and language toggle
import { useAuth } from "@/providers/auth-provider"
import { useLanguage } from "@/providers/language-provider"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { MobileSidebar } from "./sidebar"
import { NotificationsBell } from "@/components/notifications-bell"
import { LogOut, User, Languages, ChevronDown } from "lucide-react"
import { cn } from "@/lib/utils"

export function Header() {
  const { user, logout } = useAuth()
  const { language, toggleLanguage, t } = useLanguage()

  const handleLogout = async () => {
    await logout()
  }

  const getInitials = (name: string) => {
    return name
      .split(" ")
      .map((n) => n[0])
      .join("")
      .toUpperCase()
      .slice(0, 2)
  }

  const initials = user?.name ? getInitials(user.name) : "AD"

  return (
    <header className="sticky top-0 z-30 flex h-14 items-center gap-3 border-b border-border/60 bg-background/90 backdrop-blur-md px-4 lg:px-6">
      <MobileSidebar />

      <div className="flex-1" />

      <div className="flex items-center gap-2">
        {/* Language Toggle */}
        <button
          onClick={toggleLanguage}
          className={cn(
            "flex items-center gap-1.5 h-8 px-3 rounded-full text-xs font-semibold transition-all duration-150",
            "text-muted-foreground hover:text-foreground bg-muted/50 hover:bg-muted border border-border/60 hover:border-border"
          )}
          title={language === "en" ? t("tooltipSwitchToArabic") : t("tooltipSwitchToEnglish")}
        >
          <Languages className="h-3.5 w-3.5" />
          <span>{t("languageToggleLabel")}</span>
        </button>

        {/* Notification Bell */}
        <NotificationsBell />

        {/* User Menu */}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button className="flex items-center gap-2 h-8 pl-1 pr-2 rounded-full hover:bg-muted transition-all duration-150 group">
              <Avatar className="h-7 w-7">
                <AvatarFallback className="bg-indigo-100 text-indigo-700 text-[11px] font-bold">
                  {initials}
                </AvatarFallback>
              </Avatar>
              <span className="hidden sm:block text-xs font-semibold text-foreground/80 group-hover:text-foreground max-w-[100px] truncate">
                {user?.name ?? "Admin"}
              </span>
              <ChevronDown className="hidden sm:block h-3 w-3 text-muted-foreground" />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent className="w-56" align={language === "ar" ? "start" : "end"} forceMount>
            <DropdownMenuLabel className="font-normal">
              <div className="flex flex-col space-y-1">
                <p className="text-sm font-semibold leading-none">{user?.name}</p>
                <p className="text-xs leading-none text-muted-foreground">{user?.email}</p>
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem disabled>
              <User className="mr-2 h-4 w-4 rtl:mr-0 rtl:ml-2" />
              <span>{t("profile")}</span>
            </DropdownMenuItem>
            <DropdownMenuItem onClick={handleLogout} className="text-destructive focus:text-destructive">
              <LogOut className="mr-2 h-4 w-4 rtl:mr-0 rtl:ml-2" />
              <span>{t("logOut")}</span>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  )
}
