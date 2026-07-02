import CheerPlanCore
import CheerPlanUI
import MapKit
import SwiftUI

/// The course polyline plus start/finish markers, shared by every map screen.
/// The Core↔MapKit conversion lives at this boundary — packages stay MapKit-free.
struct CourseMapContent: MapContent {
    let course: Course

    var body: some MapContent {
        MapPolyline(coordinates: course.points.map { mapCoordinate($0.coordinate) })
            .stroke(CheerPlanColors.course, lineWidth: 4)
        markers
    }

    /// Combined Start/Finish marker on loop courses (start–finish < 50 m).
    @MapContentBuilder private var markers: some MapContent {
        if course.isLoop {
            if let start = course.start {
                Marker("Start / Finish", systemImage: "flag.checkered", coordinate: mapCoordinate(start))
            }
        } else {
            if let start = course.start {
                Marker("Start", systemImage: "flag", coordinate: mapCoordinate(start))
            }
            if let finish = course.finish {
                Marker("Finish", systemImage: "flag.checkered", coordinate: mapCoordinate(finish))
            }
        }
    }
}

func mapCoordinate(_ coordinate: Coordinate) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
}
