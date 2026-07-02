import CheerPlanCore
import MapKit
import SwiftUI

/// MapKit rendering of a bare course (runner's view).
struct CourseMapView: View {
    let course: Course

    var body: some View {
        Map(initialPosition: .automatic) {
            CourseMapContent(course: course)
        }
        .mapStyle(.standard(elevation: .flat))
    }
}

#Preview {
    CourseMapView(course: PreviewData.course)
}
