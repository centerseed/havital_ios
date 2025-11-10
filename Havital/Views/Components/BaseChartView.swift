import SwiftUI
import Charts

struct BaseChartView<T: ChartDataPoint, VM: BaseChartViewModel<T>>: View {
    @ObservedObject var viewModel: VM
    let title: String
    let emptyMessage: String
    
    init(viewModel: VM, title: String = "", emptyMessage: String = "無可用數據") {
        self.viewModel = viewModel
        self.title = title
        self.emptyMessage = emptyMessage
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else if viewModel.dataPoints.isEmpty {
                Text(emptyMessage)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else {
                chartView
            }
        }
        .task {
            await TrackedTask("BaseChartView: loadData") {
                await viewModel.loadData()
            }.value
        }
    }
    
    private var chartView: some View {
        Chart {
            ForEach(viewModel.dataPoints, id: \.date) { point in
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("數值", point.value)
                )
                .foregroundStyle(viewModel.chartColor.gradient)
                
                if let selected = viewModel.selectedPoint, selected.date == point.date {
                    PointMark(
                        x: .value("日期", point.date),
                        y: .value("數值", point.value)
                    )
                    .foregroundStyle(viewModel.chartColor)
                    .symbolSize(100)
                    .annotation(position: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.date.formatted(.dateTime.month().day()))
                                .font(.caption)
                            Text(String(format: "%.1f", point.value))
                                .font(.caption.bold())
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(radius: 2)
                        )
                    }
                }
            }
            
            if let selected = viewModel.selectedPoint {
                RuleMark(
                    x: .value("Selected", selected.date)
                )
                .foregroundStyle(Color.gray.opacity(0.3))
            }
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.month().day()))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYScale(domain: viewModel.yAxisRange ?? 0...100)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                guard x >= 0, x <= geometry[proxy.plotAreaFrame].width else {
                                    viewModel.selectedPoint = nil
                                    return
                                }
                                
                                let date = proxy.value(atX: x, as: Date.self)!
                                viewModel.selectedPoint = viewModel.findClosestPoint(to: date)
                            }
                            .onEnded { _ in
                                viewModel.selectedPoint = nil
                            }
                    )
            }
        }
    }
}
