import axios from "axios"
import type { User } from "@/types/models"

/** The user's id: the API sends `id` (UUID); older code expected `_id`. */
export function userIdOf(user: Pick<User, "_id"> & { id?: string }): string {
  return user.id ?? user._id
}

/** Banned through the ban action (POST /admin/users/:id/ban), which sets `bannedAt`. */
export function isBanned(user: Pick<User, "bannedAt">): boolean {
  return user.bannedAt != null
}

/** Shown as banned: banned, or deactivated another way. */
export function looksBanned(user: Pick<User, "bannedAt" | "isActive">): boolean {
  return isBanned(user) || user.isActive === false
}

/** The server's own explanation of a refused request, when it gave one. */
export function apiErrorMessage(error: unknown): string | null {
  if (!axios.isAxiosError(error)) return null
  const body = error.response?.data as
    | { error?: { message?: unknown }; message?: unknown }
    | undefined
  const message = body?.error?.message ?? body?.message
  return typeof message === "string" && message.trim() ? message : null
}
