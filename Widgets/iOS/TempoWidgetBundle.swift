import WidgetKit
import SwiftUI

@main
struct TempoWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextEventWidget()
        AgendaWidget()
        MonthAgendaWidget()
        MonthWidget()
        DayTimelineWidget()
        WeekScheduleWidget()
        SetSwitcherWidget()
        TodayGlanceWidget()
    }
}
