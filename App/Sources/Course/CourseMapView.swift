import CheerPlanCore
import CheerPlanUI
import MapKit
import SwiftUI

/// MapKit rendering of a course. The Core↔MapKit conversion lives here —
/// the packages stay free of MapKit (spec §5).
struct CourseMapView: View {
    let course: Course

    var body: some View {
        Map(initialPosition: .automatic) {
            MapPolyline(coordinates: polyline)
                .stroke(CheerPlanColors.course, lineWidth: 4)
            markers
        }
        .mapStyle(.standard(elevation: .flat))
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

    private var polyline: [CLLocationCoordinate2D] {
        course.points.map { mapCoordinate($0.coordinate) }
    }

    private func mapCoordinate(_ coordinate: Coordinate) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

#Preview {
    CourseMapView(course: PreviewData.course)
}
