import WidgetKit
import SwiftUI

@main
struct TempoWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextEventWidget()
        TodayGlanceWidget()
    }
}
