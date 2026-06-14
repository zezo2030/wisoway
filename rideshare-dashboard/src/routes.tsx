// Routes: Route definitions with protected route guard
// T012: Defines all routes with authentication guards

import { Navigate, useRoutes } from "react-router-dom"
import { useAuth } from "@/providers/auth-provider"
import { AppLayout } from "@/components/layout/app-layout"
import LoginPage from "@/pages/login"
import DashboardPage from "@/pages/dashboard"
import UsersListPage from "@/pages/users/users-list"
import UserDetailPage from "@/pages/users/user-detail"
import PaymentsListPage from "@/pages/payments/payments-list"
import PendingQueuePage from "@/pages/payments/pending-queue"
import WalletsListPage from "@/pages/wallets/wallets-list"
import WalletDetailPage from "@/pages/wallets/wallet-detail"
import VehiclesListPage from "@/pages/vehicles/vehicles-list"
import TripsListPage from "@/pages/trips/trips-list"
import TripDetailPage from "@/pages/trips/trip-detail"
import ReportsPage from "@/pages/reports/reports"
import PricingSettingsPage from "@/pages/settings/pricing-settings"
import BookingsListPage from "@/pages/bookings/bookings-list"
import RatingsListPage from "@/pages/ratings/ratings-list"
import NotificationsPage from "@/pages/notifications/notifications"
import ChatRoomsPage from "@/pages/chat/chat-rooms"
import TripChatLivePage from "@/pages/chat/trip-chat-live"
import AccountFlagsPage from "@/pages/account-flags/account-flags"
import PendingChargesPage from "@/pages/pending-charges/PendingChargesPage"
import ComplaintsPage from "@/pages/complaints/complaints"
import RefundsPage from "@/pages/refunds/refunds"
import FinesPage from "@/pages/fines/fines-list"
import NoShowReportsPage from "@/pages/no-show-reports/no-show-reports-list"

// Placeholder pages (will be implemented in later phases)

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth()

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-slate-900" />
      </div>
    )
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}

export function AppRoutes() {
  const routes = useRoutes([
    {
      path: "/",
      element: <Navigate to="/dashboard" replace />,
    },
    {
      path: "/login",
      element: <LoginPage />,
    },
    {
      path: "/",
      element: (
        <ProtectedRoute>
          <AppLayout />
        </ProtectedRoute>
      ),
      children: [
        {
          path: "dashboard",
          element: <DashboardPage />,
        },
        {
          path: "users",
          element: <UsersListPage />,
        },
        {
          path: "users/:id",
          element: <UserDetailPage />,
        },
        {
          path: "payments",
          element: <PaymentsListPage />,
        },
        {
          path: "payments/pending",
          element: <PendingQueuePage />,
        },
        {
          path: "wallets",
          element: <WalletsListPage />,
        },
        {
          path: "wallets/:id",
          element: <WalletDetailPage />,
        },
        {
          path: "vehicles",
          element: <VehiclesListPage />,
        },
        {
          path: "trips",
          element: <TripsListPage />,
        },
        {
          path: "trips/:id",
          element: <TripDetailPage />,
        },
        {
          path: "trips/:id/chat",
          element: <TripChatLivePage />,
        },
        {
          path: "bookings",
          element: <BookingsListPage />,
        },
        {
          path: "ratings",
          element: <RatingsListPage />,
        },
        {
          path: "notifications",
          element: <NotificationsPage />,
        },
        {
          path: "chat",
          element: <ChatRoomsPage />,
        },
        {
          path: "reports",
          element: <ReportsPage />,
        },
        {
          path: "settings/pricing",
          element: <PricingSettingsPage />,
        },
        {
          path: "account-flags",
          element: <AccountFlagsPage />,
        },
        {
          path: "pending-charges",
          element: <PendingChargesPage />,
        },
        {
          path: "complaints",
          element: <ComplaintsPage />,
        },
        {
          path: "refunds",
          element: <RefundsPage />,
        },
        {
          path: "fines",
          element: <FinesPage />,
        },
        {
          path: "no-show-reports",
          element: <NoShowReportsPage />,
        },
      ],
    },
    {
      path: "*",
      element: <Navigate to="/dashboard" replace />,
    },
  ])

  return routes
}

