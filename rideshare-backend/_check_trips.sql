SELECT COUNT(*) AS total_trips FROM trips;
SELECT id, status, "isVisible", "fromName", "toName", "departureTime", "availableSeats", "driverId", "createdAt"
FROM trips
ORDER BY "createdAt" DESC
LIMIT 10;
