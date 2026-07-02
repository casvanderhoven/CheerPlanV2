import Foundation

/// The runner's position⇄time bijection for one pacing strategy.
///
/// Both directions are piecewise-linear interpolation over cumulative
/// (distance, time) breakpoints — a steady pace has two, split-based pacing one per
/// split boundary — found by binary search and exactly invertible on the course.
public struct PaceModel: Sendable {
    private let distances: [Double]
    private let times: [Double]
    public let courseDistance: Double

    public init(pacing: PacingStrategy, courseDistance: Double) {
        let course = max(0, courseDistance)
        self.courseDistance = course
        var distances: [Double] = [0]
        var times: [Double] = [0]

        switch pacing {
        case .steady(let secondsPerKilometer):
            if course > 0 {
                let pace = Self.metersPace(secondsPerKilometer)
                distances.append(course)
                times.append(course * pace)
            }
        case .splits(let splits):
            var distance = 0.0
            var time = 0.0
            var lastPace = Self.metersPace(300) // 5:00/km fallback if splits are empty
            for split in splits where split.distance > 0 && distance < course {
                let pace = Self.metersPace(split.secondsPerKilometer)
                lastPace = pace
                let end = min(distance + split.distance, course)
                if end > distance {
                    time += (end - distance) * pace
                    distance = end
                    distances.append(distance)
                    times.append(time)
                }
            }
            if distance < course {
                // Splits fall short of the course: the final pace extends to the finish.
                time += (course - distance) * lastPace
                distances.append(course)
                times.append(time)
            }
        }

        self.distances = distances
        self.times = times
    }

    public var totalDuration: TimeInterval {
        times.last ?? 0
    }

    /// Seconds after the start when the runner reaches `distance` meters.
    /// Clamped to `[0, totalDuration]`.
    public func time(atDistance distance: Double) -> TimeInterval {
        Self.interpolate(distance, from: distances, to: times)
    }

    /// Meters covered `elapsed` seconds after the start. Clamped to `[0, courseDistance]`.
    public func distance(atTime elapsed: TimeInterval) -> Double {
        Self.interpolate(elapsed, from: times, to: distances)
    }

    /// Seconds per meter, guarded against zero/negative paces.
    private static func metersPace(_ secondsPerKilometer: Double) -> Double {
        max(0.001, secondsPerKilometer) / 1000
    }

    /// Piecewise-linear map from `source` breakpoints to `target` breakpoints,
    /// clamped at both ends. `source` must be non-decreasing.
    private static func interpolate(_ value: Double, from source: [Double], to target: [Double]) -> Double {
        guard let firstSource = source.first, let lastSource = source.last,
              let firstTarget = target.first, let lastTarget = target.last else {
            return 0
        }
        if value <= firstSource { return firstTarget }
        if value >= lastSource { return lastTarget }

        var low = 0
        var high = source.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if source[mid] <= value {
                low = mid
            } else {
                high = mid
            }
        }
        let span = source[high] - source[low]
        guard span > 0 else { return target[low] }
        let fraction = (value - source[low]) / span
        return target[low] + fraction * (target[high] - target[low])
    }
}
