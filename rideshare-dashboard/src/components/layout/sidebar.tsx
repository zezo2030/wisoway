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
  ShieldAlert,
  Zap,
  Gavel,
  AlertTriangle,
  FileText,
} from "lucide-react"
import { useState } from "react"
import { ROUTES } from "@/lib/constants"
import type { TranslationKey } from "@/i18n/translations"

const NAV_GROUPS: { labelKey: TranslationKey; items: { path: string; labelKey: TranslationKey; icon: string }[] }[] = [
  {
    labelKey: "navGroupMain",
    items: [
      { path: ROUTES.DASHBOARD, labelKey: "nav_dashboard", icon: "LayoutDashboard" },
      { path: ROUTES.TRIPS, labelKey: "nav_trips", icon: "MapPin" },
      { path: ROUTES.BOOKINGS, labelKey: "nav_bookings", icon: "BookOpen" },
    ],
  },
  {
    labelKey: "navGroupManagement",
    items: [
      { path: ROUTES.USERS, labelKey: "nav_users", icon: "Users" },
      { path: ROUTES.VEHICLES, labelKey: "nav_vehicles", icon: "Car" },
      { path: ROUTES.PAYMENTS, labelKey: "nav_payments", icon: "CreditCard" },
      { path: ROUTES.WALLETS, labelKey: "nav_wallets", icon: "Wallet" },
      { path: ROUTES.ACCOUNT_FLAGS, labelKey: "nav_accountFlags", icon: "ShieldAlert" },
      { path: ROUTES.FINES, labelKey: "nav_fines", icon: "Gavel" },
      { path: ROUTES.NO_SHOW_REPORTS, labelKey: "nav_noShowReports", icon: "AlertTriangle" },
    ],
  },
  {
    labelKey: "navGroupInsights",
    items: [
      { path: ROUTES.REPORTS, labelKey: "nav_reports", icon: "BarChart3" },
      { path: ROUTES.RATINGS, labelKey: "nav_ratings", icon: "Star" },
      { path: ROUTES.NOTIFICATIONS, labelKey: "nav_notifications", icon: "Bell" },
      { path: ROUTES.CHAT, labelKey: "nav_chat", icon: "MessageSquare" },
      { path: ROUTES.PRICING_SETTINGS, labelKey: "nav_pricing", icon: "Percent" },
    ],
  },
  {
    labelKey: "navGroupLegal",
    items: [{ path: ROUTES.PRIVACY, labelKey: "nav_privacyPolicy", icon: "FileText" }],
  },
]

const iconMap: Record<string, React.ComponentType<{ className?: string }>> = {
  LayoutDashboard, Users, CreditCard, Wallet, Car, MapPin, BarChart3,
  BookOpen, Star, Bell, MessageSquare, Percent, ShieldAlert, Gavel,
  AlertTriangle, FileText,
}

interface SidebarProps {
  className?: string
}

function SidebarNav({ collapsed, onNavClick }: { collapsed?: boolean; onNavClick?: () => void }) {
  const { t } = useLanguage()
  return (
    <ScrollArea className="flex-1 py-4">
      <nav className="flex flex-col px-3 gap-5">
        {NAV_GROUPS.map((group) => (
          <div key={group.labelKey}>
            {!collapsed && (
              <p className="text-[10px] font-extrabold uppercase tracking-[0.12em] text-white/25 mb-2 px-2">
                {t(group.labelKey)}
              </p>
            )}
            <div className="flex flex-col gap-0.5">
              {group.items.map((item) => {
                const Icon = iconMap[item.icon]
                return (
                  <NavLink
                    key={item.path}
                    to={item.path}
                    onClick={onNavClick}
                    title={collapsed ? t(item.labelKey) : undefined}
                    className={({ isActive }) =>
                      cn(
                        "flex items-center gap-2.5 rounded-lg text-[13px] font-medium transition-all duration-150",
                        collapsed ? "justify-center p-2.5" : "px-2.5 py-2",
                        isActive
                          ? "bg-white/10 text-white"
                          : "text-white/45 hover:text-white/80 hover:bg-white/6"
                      )
                    }
                  >
                    {({ isActive }) => (
                      <>
                        {Icon && (
                          <Icon className={cn(
                            "flex-shrink-0 transition-colors",
                            collapsed ? "h-5 w-5" : "h-4 w-4",
                            isActive ? "text-indigo-300" : ""
                          )} />
                        )}
                        {!collapsed && (
                          <span className="truncate flex-1">{t(item.labelKey)}</span>
                        )}
                        {isActive && !collapsed && (
                          <span className="w-1.5 h-1.5 rounded-full bg-indigo-400 flex-shrink-0" />
                        )}
                      </>
                    )}
                  </NavLink>
                )
              })}
            </div>
          </div>
        ))}
      </nav>
    </ScrollArea>
  )
}

export function Sidebar({ className }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false)
  const { t, language } = useLanguage()
  const isRtl = language === "ar"

  return (
    <div
      className={cn(
        "flex flex-col h-screen transition-all duration-300 ease-in-out",
        "bg-[#0b0f1e] border-r border-white/[0.06]",
        collapsed ? "w-[68px]" : "w-[240px]",
        className
      )}
    >
      {/* Brand */}
      <div className={cn(
        "flex h-16 items-center border-b border-white/[0.06] px-4 gap-3 flex-shrink-0",
        collapsed && "justify-center px-0"
      )}>
        <div className="flex-shrink-0 w-8 h-8 rounded-xl bg-indigo-500 flex items-center justify-center shadow-lg shadow-indigo-500/40">
          <Zap className="w-[18px] h-[18px] text-white" />
        </div>
        {!collapsed && (
          <span className="font-bold text-white text-[15px] tracking-tight truncate leading-none">
            {t("adminDashboard")}
          </span>
        )}
      </div>

      <SidebarNav collapsed={collapsed} />

      {/* Collapse toggle */}
      <div className="border-t border-white/[0.06] p-3 flex-shrink-0">
        <button
          className={cn(
            "flex items-center gap-2 w-full rounded-lg px-2.5 py-2 text-white/30 hover:text-white/60 hover:bg-white/5 transition-all duration-150 text-xs font-medium",
            collapsed && "justify-center px-0"
          )}
          onClick={() => setCollapsed(!collapsed)}
        >
          <ChevronLeft
            className={cn(
              "h-4 w-4 flex-shrink-0 transition-transform duration-300",
              collapsed && !isRtl && "rotate-180",
              !collapsed && isRtl && "rotate-180",
            )}
          />
          {!collapsed && <span>{t("collapse")}</span>}
        </button>
      </div>
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
      <SheetContent
        side={language === "ar" ? "right" : "left"}
        className="w-[240px] p-0 bg-[#0b0f1e] border-white/[0.06]"
      >
        <div className="flex flex-col h-full">
          <div className="flex h-16 items-center border-b border-white/[0.06] px-4 gap-3 flex-shrink-0">
            <div className="w-8 h-8 rounded-xl bg-indigo-500 flex items-center justify-center shadow-lg shadow-indigo-500/40">
              <Zap className="w-[18px] h-[18px] text-white" />
            </div>
            <span className="font-bold text-white text-[15px]">{t("adminDashboard")}</span>
          </div>
          <SidebarNav onNavClick={() => setOpen(false)} />
        </div>
      </SheetContent>
    </Sheet>
  )
}
