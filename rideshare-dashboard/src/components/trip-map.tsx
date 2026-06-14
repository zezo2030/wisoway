// TripMap: Shows trip route with live driver tracking on an interactive Leaflet map
import { useEffect, useMemo } from "react"
import { useQuery } from "@tanstack/react-query"
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from "react-leaflet"
import L from "leaflet"
import "leaflet/dist/leaflet.css"
import type { Location, TripStop } from "@/types/models"
import { getTripTrackingHistory, getTripTrackingLatest } from "@/api/admin"

// Fix Leaflet default icon paths broken by bundlers
delete (L.Icon.Default.prototype as unknown as Record<string, unknown>)._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
})

const fromIcon = new L.Icon({
  iconUrl: "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
})

const toIcon = new L.Icon({
  iconUrl: "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
})

const stopIcon = new L.Icon({
  iconUrl: "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-orange.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [20, 33],
  iconAnchor: [10, 33],
  popupAnchor: [1, -28],
  shadowSize: [33, 33],
})

const driverIcon = new L.Icon({
  iconUrl: "https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
  shadowSize: [41, 41],
})

function FitBounds({ positions }: { positions: [number, number][] }) {
  const map = useMap()
  useEffect(() => {
    if (positions.length > 1) {
      map.fitBounds(L.latLngBounds(positions), { padding: [48, 48] })
    } else if (positions.length === 1) {
      map.setView(positions[0], 13)
    }
  }, [map, positions])
  return null
}

interface TripMapProps {
  from?: Location | string
  to?: Location | string
  stops?: TripStop[]
  fromName?: string
  toName?: string
  trip?: Record<string, unknown>
  tripId?: string
}

function toNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : null
  }
  return null
}

function getLatLngFromLocation(val: unknown): [number, number] | null {
  if (!val || typeof val !== "object") return null
  const obj = val as Record<string, unknown>

  const lat = toNumber(obj.latitude) ?? toNumber(obj.lat)
  const lng = toNumber(obj.longitude) ?? toNumber(obj.lng)

  if (lat == null || lng == null) return null
  return [lat, lng]
}

function getLatLngFromGeoPoint(val: unknown): [number, number] | null {
  if (!val || typeof val !== "object") return null
  const obj = val as Record<string, unknown>
  const coordinates = obj.coordinates
  if (!Array.isArray(coordinates) || coordinates.length < 2) return null

  const lng = toNumber(coordinates[0])
  const lat = toNumber(coordinates[1])
  if (lat == null || lng == null) return null
  return [lat, lng]
}

function getTripPoint(trip: Record<string, unknown> | undefined, key: "from" | "to"): [number, number] | null {
  if (!trip) return null

  const direct = getLatLngFromLocation(trip[key])
  if (direct) return direct

  const geoPoint = getLatLngFromGeoPoint(trip[key === "from" ? "fromPoint" : "toPoint"])
  if (geoPoint) return geoPoint

  const lat = toNumber(trip[key === "from" ? "fromLatitude" : "toLatitude"])
  const lng = toNumber(trip[key === "from" ? "fromLongitude" : "toLongitude"])
  if (lat != null && lng != null) return [lat, lng]

  return null
}

function normalizeStopPoints(stopsInput: unknown): [number, number][] {
  if (!Array.isArray(stopsInput)) return []

  return stopsInput
    .slice()
    .sort((a, b) => {
      const aOrder = typeof a === "object" && a !== null ? toNumber((a as Record<string, unknown>).order) ?? 0 : 0
      const bOrder = typeof b === "object" && b !== null ? toNumber((b as Record<string, unknown>).order) ?? 0 : 0
      return aOrder - bOrder
    })
    .map((stop) => {
      if (!stop || typeof stop !== "object") return null
      const obj = stop as Record<string, unknown>
      const lat = toNumber(obj.lat) ?? toNumber(obj.latitude)
      const lng = toNumber(obj.lng) ?? toNumber(obj.longitude)
      if (lat == null || lng == null) return null
      return [lat, lng] as [number, number]
    })
    .filter((point): point is [number, number] => point !== null)
}

export function TripMap({ from, to, stops, fromName, toName, trip, tripId }: TripMapProps) {
  const fromPoint = getLatLngFromLocation(from) ?? getTripPoint(trip, "from")
  const toPoint = getLatLngFromLocation(to) ?? getTripPoint(trip, "to")

  const allPositions: [number, number][] = []
  if (fromPoint) allPositions.push(fromPoint)

  const stopPositions = normalizeStopPoints(stops ?? trip?.stops)

  allPositions.push(...stopPositions)
  if (toPoint) allPositions.push(toPoint)

  const routeWaypoints = allPositions

  const routeKey = useMemo(() => routeWaypoints.map(([lat, lng]) => `${lat.toFixed(6)},${lng.toFixed(6)}`).join("|"), [routeWaypoints])

  const { data: roadRoute } = useQuery({
    queryKey: ["trip-road-route", routeKey],
    enabled: routeWaypoints.length >= 2,
    staleTime: 1000 * 60 * 10,
    queryFn: async (): Promise<[number, number][]> => {
      const coords = routeWaypoints.map(([lat, lng]) => `${lng},${lat}`).join(";")
      const url = `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=false`
      const response = await fetch(url)
      if (!response.ok) throw new Error("Failed to fetch road route")

      const payload = await response.json() as {
        routes?: Array<{ geometry?: { coordinates?: Array<[number, number]> } }>
      }

      const coordinates = payload.routes?.[0]?.geometry?.coordinates ?? []
      if (!coordinates.length) throw new Error("Empty route geometry")
      return coordinates.map(([lng, lat]) => [lat, lng])
    },
  })

  const { data: latestTracking } = useQuery({
    queryKey: ["trip-tracking-latest", tripId],
    enabled: !!tripId,
    refetchInterval: 10000,
    queryFn: () => getTripTrackingLatest(tripId!),
  })

  const { data: trackingHistory } = useQuery({
    queryKey: ["trip-tracking-history", tripId],
    enabled: !!tripId,
    refetchInterval: 10000,
    queryFn: () => getTripTrackingHistory(tripId!, 300),
  })

  const historyPositions = useMemo<[number, number][]>(() => {
    if (!trackingHistory || trackingHistory.length === 0) return []
    return [...trackingHistory]
      .reverse()
      .map((p) => [p.latitude, p.longitude] as [number, number])
  }, [trackingHistory])

  const fallbackDriverPoint = useMemo<[number, number] | null>(() => {
    const lat = toNumber(trip?.lastDriverLocationLat)
    const lng = toNumber(trip?.lastDriverLocationLng)
    return lat != null && lng != null ? [lat, lng] : null
  }, [trip])

  const driverPoint = latestTracking
    ? [latestTracking.latitude, latestTracking.longitude] as [number, number]
    : fallbackDriverPoint

  const routePolyline = roadRoute && roadRoute.length > 1 ? roadRoute : routeWaypoints

  const fitPositions = [...routePolyline, ...historyPositions]
  if (driverPoint) fitPositions.push(driverPoint)

  const center: [number, number] =
    fitPositions.length > 0
      ? fitPositions[Math.floor(fitPositions.length / 2)]
      : [30.0444, 31.2357] // Cairo fallback

  if (fitPositions.length === 0) {
    return (
      <div className="flex items-center justify-center h-64 rounded-2xl bg-muted/40 border border-border/40 text-muted-foreground text-sm font-medium">
        No location data available for this trip.
      </div>
    )
  }

  return (
    <div className="relative rounded-2xl overflow-hidden border border-border/40 shadow-inner" style={{ height: 380 }}>
      <MapContainer
        center={center}
        zoom={10}
        style={{ height: "100%", width: "100%" }}
        scrollWheelZoom={true}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <FitBounds positions={fitPositions} />

        {/* Planned road route */}
        {routePolyline.length > 1 && (
          <Polyline
            positions={routePolyline}
            color="#6366f1"
            weight={4}
            opacity={0.8}
            dashArray={roadRoute && roadRoute.length > 1 ? undefined : "8 4"}
          />
        )}

        {/* Live traveled track */}
        {historyPositions.length > 1 && (
          <Polyline
            positions={historyPositions}
            color="#ef4444"
            weight={3.5}
            opacity={0.9}
          />
        )}

        {/* From marker */}
        {fromPoint && (
          <Marker position={fromPoint} icon={fromIcon}>
            <Popup>
              <div className="font-semibold">Departure</div>
              <div className="text-sm text-gray-600">
                {fromName || (typeof from === "object" && from && "name" in from ? (from as { name?: string }).name : undefined) || (trip?.fromName as string | undefined) || "Start"}
              </div>
            </Popup>
          </Marker>
        )}

        {/* Stop markers */}
        {((Array.isArray(stops ?? trip?.stops) ? (stops ?? trip?.stops) : []) as unknown[])
          .slice()
          .sort((a: unknown, b: unknown) => {
            const aOrder = typeof a === "object" && a !== null ? toNumber((a as Record<string, unknown>).order) ?? 0 : 0
            const bOrder = typeof b === "object" && b !== null ? toNumber((b as Record<string, unknown>).order) ?? 0 : 0
            return aOrder - bOrder
          })
          .map((stop: unknown, i: number) => {
            if (!stop || typeof stop !== "object") return null
            const obj = stop as Record<string, unknown>
            const lat = toNumber(obj.lat) ?? toNumber(obj.latitude)
            const lng = toNumber(obj.lng) ?? toNumber(obj.longitude)
            if (lat == null || lng == null) return null

            return (
            <Marker key={i} position={[lat, lng]} icon={stopIcon}>
              <Popup>
                <div className="font-semibold">Stop {i + 1}</div>
                <div className="text-sm text-gray-600">{typeof obj.name === "string" ? obj.name : `Stop ${i + 1}`}</div>
                {typeof obj.note === "string" && <div className="text-xs text-gray-400 mt-1 italic">{obj.note}</div>}
              </Popup>
            </Marker>
          )})}

        {/* To marker */}
        {toPoint && (
          <Marker position={toPoint} icon={toIcon}>
            <Popup>
              <div className="font-semibold">Destination</div>
              <div className="text-sm text-gray-600">
                {toName || (typeof to === "object" && to && "name" in to ? (to as { name?: string }).name : undefined) || (trip?.toName as string | undefined) || "End"}
              </div>
            </Popup>
          </Marker>
        )}

        {/* Live driver marker */}
        {driverPoint && (
          <Marker position={driverPoint} icon={driverIcon}>
            <Popup>
              <div className="font-semibold">Driver (Live)</div>
              {latestTracking?.recordedAt && (
                <div className="text-xs text-gray-500 mt-1">
                  Updated: {new Date(latestTracking.recordedAt).toLocaleString()}
                </div>
              )}
            </Popup>
          </Marker>
        )}
      </MapContainer>

      {/* Legend overlay */}
      <div className="absolute bottom-3 left-3 z-[1000] flex flex-col gap-1.5 bg-background/90 backdrop-blur-sm border border-border/50 rounded-xl px-3 py-2.5 shadow-md">
        <div className="flex items-center gap-2 text-xs font-semibold">
          <span className="w-3 h-3 rounded-full bg-blue-500 flex-shrink-0" /> Departure
        </div>
        {stopPositions.length > 0 && (
          <div className="flex items-center gap-2 text-xs font-semibold">
            <span className="w-3 h-3 rounded-full bg-orange-500 flex-shrink-0" /> Stops ({stopPositions.length})
          </div>
        )}
        <div className="flex items-center gap-2 text-xs font-semibold">
          <span className="w-3 h-3 rounded-full bg-emerald-500 flex-shrink-0" /> Destination
        </div>
        {driverPoint && (
          <div className="flex items-center gap-2 text-xs font-semibold">
            <span className="w-3 h-3 rounded-full bg-red-500 flex-shrink-0" /> Live Driver
          </div>
        )}
        {historyPositions.length > 1 && (
          <div className="flex items-center gap-2 text-xs font-semibold">
            <span className="w-3 h-3 rounded-full bg-rose-500 flex-shrink-0" /> Traveled Path
          </div>
        )}
      </div>
    </div>
  )
}
