import type { Notification } from "@/types/models"

/**
 * Where a notification leads in the dashboard. Admin alerts carry their own
 * `data.link` (a complaint, a trip, a payment queue…); older ones are matched
 * by what they reference. Null when there is nowhere better than the inbox.
 */
export function notificationLink(n: Pick<Notification, "type" | "data">): string | null {
  const data = (n.data ?? {}) as Record<string, unknown>
  const link = data.link
  if (typeof link === "string" && link.startsWith("/") && !link.startsWith("//")) {
    return link
  }
  const id = (key: string) => {
    const value = data[key]
    return typeof value === "string" && value ? encodeURIComponent(value) : null
  }
  if (n.type === "new_user_registered" && id("newUserId")) return `/users/${id("newUserId")}`
  if (id("tripId")) return `/trips/${id("tripId")}`
  if (id("complaintId")) return "/complaints"
  if (id("refundId")) return "/refunds"
  if (id("payoutId")) return "/wallets"
  return null
}
