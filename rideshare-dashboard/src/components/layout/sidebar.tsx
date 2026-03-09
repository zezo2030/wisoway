// Sidebar: Navigation component with links to all admin sections
// T011: Part of app layout shell

import { NavLink } from "react-router-dom"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet"
import { NAV_ITEMS } from "@/lib/constants"
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
} from "lucide-react"
import { useState } from "react"

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
}

interface SidebarProps {
  className?: string
}

export function Sidebar({ className }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false)

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
          <span className="font-semibold text-lg truncate">Admin Dashboard</span>
        )}
        <Button
          variant="ghost"
          size="icon"
          className={cn("ml-auto", collapsed && "ml-0")}
          onClick={() => setCollapsed(!collapsed)}
        >
          <ChevronLeft
            className={cn(
              "h-4 w-4 transition-transform",
              collapsed && "rotate-180"
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
                {!collapsed && <span className="truncate">{item.label}</span>}
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

  // Close mobile sidebar on route change
  useState(() => {
    setOpen(false)
  })

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="icon" className="lg:hidden">
          <Menu className="h-5 w-5" />
          <span className="sr-only">Toggle menu</span>
        </Button>
      </SheetTrigger>
      <SheetContent side="left" className="w-64 p-0">
        <div className="flex flex-col h-full">
          <div className="flex h-14 items-center border-b px-4">
            <span className="font-semibold text-lg">Admin Dashboard</span>
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
                    <span>{item.label}</span>
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
