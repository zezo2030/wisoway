import assert from "node:assert/strict"
import { notificationLink } from "../lib/notification-link"

// Admin alerts say where they lead.
assert.equal(notificationLink({ type: "admin_complaint", data: { link: "/complaints", complaintId: "c1" } }), "/complaints")
assert.equal(notificationLink({ type: "admin_trip_emergency", data: { link: "/trips/t1" } }), "/trips/t1")
// Never off the dashboard.
assert.equal(notificationLink({ type: "x", data: { link: "//evil.example" } }), null)
assert.equal(notificationLink({ type: "x", data: { link: "https://evil.example" } }), null)
// Older ones by what they reference.
assert.equal(notificationLink({ type: "new_user_registered", data: { newUserId: "u1" } }), "/users/u1")
assert.equal(notificationLink({ type: "presence_conflict_admin", data: { tripId: "t2", driverId: "d" } }), "/trips/t2")
assert.equal(notificationLink({ type: "admin_broadcast", data: {} }), null)
assert.equal(notificationLink({ type: "admin_broadcast", data: undefined }), null)
console.log("Notification link checks passed")
