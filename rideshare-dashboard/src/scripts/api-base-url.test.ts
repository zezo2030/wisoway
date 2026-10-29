import assert from "node:assert/strict"
import { resolveApiBaseUrl } from "../lib/api-base-url"

for (const value of [undefined, "", "/api", "/api/", "/api/v1/"]) {
  assert.equal(resolveApiBaseUrl(value), "/api/v1")
}
assert.equal(resolveApiBaseUrl("https://vision-way.tech/api/"), "https://vision-way.tech/api/v1")
assert.equal(resolveApiBaseUrl("https://vision-way.tech/api/v1"), "https://vision-way.tech/api/v1")
console.log("API base URL regression checks passed")
