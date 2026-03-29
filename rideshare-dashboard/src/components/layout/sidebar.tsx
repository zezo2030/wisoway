// Sidebar: Navigation component with i18n support
import { NavLink } from "react-router-dom"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet"
import { useLanguage } from "@/providers/language-provider"
import {
  LayoutDashboard,
  Users,
  CreditCard,
  Wallet,
  Car,
  MapPin,
  BarChart3,
  Menu,
  ChevronLeft,
  BookOpen,
  Star,
  Bell,
  MessageSquare,
  Percent,
} from "lucide-react"
import { useState } from "react"
import { ROUTES } from "@/lib/constants"
import type { TranslationKey } from "@/i18n/translations"

//Nav item definitions using translation keys
const NAV_ITEMS: { path: string; labelKey: TranslationKey; icon: string }[] = [
  { path: ROUTES.DASHBOARD,         labelKey: "nav_dashboard",      icon: "LayoutDashboard" },
  { path: ROUTES.USERS,             labelKey: "nav_users",          icon: "Users" },
  { path: ROUTES.PAYMENTS,         labelKey: "nav_payments",       icon: "CreditCard" },
  { path: ROUTES.WALLETS,           labelKey: "nav_wallets",        icon: "Wallet" },
  { path: ROUTES.VEHICLES,         labelKey: "nav_vehicles",       icon: "Car" },
  { path: ROUTES.TRIPS,             labelKey: "nav_trips",          icon: "MapPin" },
  { path: ROUTES.BOOKINGS,         labelKey: "nav_bookings",       icon: "BookOpen" },
  { path: ROUTES.RATINGS,           labelKey: "nav_ratings",        icon: "Star" },
  { path: ROUTES.NOTIFICATIONS,     labelKey: "nav_notifications",  icon: "Bell" },
  { path: ROUTES.CHAT,             labelKey: "nav_chat",           icon: "MessageSquare" },
  { path: ROUTES.REPORTS,           labelKey: "nav_reports",        icon: "BarChart3" },
  { path: ROUTES.PRICING_SETTINGS, labelKey: "nav_pricing",        icon: "Percent" },
]

const iconMap: Record<string, React.ComponentType<{ className?: string }>> = {
  LayoutDashboard,
  Users,
  CreditCard,
  Wallet,
  Car,
  MapPin,
  BarChart3,
  BookOpen,
  Star,
  Bell,
  MessageSquare,
  Percent,
}

interface SidebarProps {
  className?: string
}

export function Sidebar({ className }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false)
  const { t, language } = useLanguage()
  const isRtl = language === "ar"

  return (
    <div
      className={cn(
        "flex flex-col h-screen border-r bg-card transition-all duration-300",
        collapsed ? "w-16" : "w-64",
        className
      )}
    >
      <div className="flex h-14 items-center border-b px-4">
        {!collapsed && (
          <span className="font-semibold text-lg truncate">{t("adminDashboard")}</span>
        )}
        <Button
          variant="ghost"
          size="icon"
          className={cn("ml-auto", collapsed && "ml-0", isRtl && "mr-auto ml-0")}
          onClick={() => setCollapsed(!collapsed)}
        >
          <ChevronLeft
            className={cn(
              "h-4 w-4 transition-transform",
              collapsed && !isRtl && "rotate-180",
              !collapsed && isRtl && "rotate-180",
              collapsed && isRtl && "rotate-0",
            )}
          />
        </Button>
      </div>
      <ScrollArea className="flex-1 py-4">
        <nav className="flex flex-col gap-2 px-2">
          {NAV_ITEMS.map((item) => {
            const Icon = iconMap[item.icon]
            return (
              <NavLink
                key={item.path}
                to={item.path}
                className={({ isActive }) =>
                  cn(
                    "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary text-primary-foreground shadow-sm"
                      : "text-muted-foreground hover:bg-muted hover:text-foreground"
                  )
                }
              >
                {Icon && <Icon className="h-4 w-4 flex-shrink-0" />}
                {!collapsed && <span className="truncate">{t(item.labelKey)}</span>}
              </NavLink>
            )
          })}
        </nav>
      </ScrollArea>
    </div>
  )
}

export function MobileSidebar() {
  const [open, setOpen] = useState(false)
  const { t, language } = useLanguage()

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="icon" className="lg:hidden">
          <Menu className="h-5 w-5" />
          <span className="sr-only">{t("toggleMenu")}</span>
        </Button>
      </SheetTrigger>
      <SheetContent side={language === "ar" ? "right" : "left"} className="w-64 p-0">
        <div className="flex flex-col h-full">
          <div className="flex h-14 items-center border-b px-4">
            <span className="font-semibold text-lg">{t("adminDashboard")}</span>
          </div>
          <ScrollArea className="flex-1 py-4">
            <nav className="flex flex-col gap-2 px-2">
              {NAV_ITEMS.map((item) => {
                const Icon = iconMap[item.icon]
                return (
                  <NavLink
                    key={item.path}
                    to={item.path}
                    onClick={() => setOpen(false)}
                    className={({ isActive }) =>
                      cn(
                        "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                        isActive
                          ? "bg-primary text-primary-foreground shadow-sm"
                          : "text-muted-foreground hover:bg-muted hover:text-foreground"
                      )
                    }
                  >
                    {Icon && <Icon className="h-4 w-4" />}
                    <span>{t(item.labelKey)}</span>
                  </NavLink>
                )
              })}
            </nav>
          </ScrollArea>
        </div>
      </SheetContent>
    </Sheet>
  )
}
