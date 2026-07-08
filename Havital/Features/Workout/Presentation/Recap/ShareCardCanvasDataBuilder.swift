enum ShareCardCanvasDataBuilder {
    static func build(from workout: WorkoutV2) -> ShareCardCanvasData {
        let paceSamples = extractPaceSamples(from: workout.timeSeries)
        let routePoints = extractRoutePoints(from: workout.routeData)
        return ShareCardCanvasData(paceSamples: paceSamples, routePoints: routePoints)
    }

    private static func extractPaceSamples(from ts: V2TimeSeries?) -> [ShareCardPaceSample] {
        guard let ts else { return [] }
        let timestamps = ts.timestampsS ?? []
        let paces = ts.pacesSPerKm ?? []
        let count = min(timestamps.count, paces.count)
        var out: [ShareCardPaceSample] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            guard let t = timestamps[i], let pace = paces[i], pace > 0, pace < 3600 else { continue }
            out.append(ShareCardPaceSample(offsetSeconds: t, paceSecondsPerKm: pace))
        }
        return out
    }

    private static func extractRoutePoints(from route: V2RouteData?) -> [ShareCardRoutePoint] {
        guard let route, let lats = route.latitudes, let lngs = route.longitudes else { return [] }
        let count = min(lats.count, lngs.count)
        var out: [ShareCardRoutePoint] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            guard let lat = lats[i], let lng = lngs[i] else { continue }
            out.append(ShareCardRoutePoint(latitude: lat, longitude: lng))
        }
        return out
    }
}
