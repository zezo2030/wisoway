/** Keep legacy deployment values such as /api aligned with Nest's v1 prefix. */
export function resolveApiBaseUrl(configured?: string): string {
  const base = configured?.trim().replace(/\/+$/, "") || "/api/v1"
  return base.endsWith("/api") ? `${base}/v1` : base
}
