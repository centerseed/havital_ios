import SwiftUI
import UniformTypeIdentifiers
import os

// MARK: - Drag Drop Handler

struct DragDropHandler {
    /// 處理拖曳結束時的邏輯
    static func handleDrop(
        from sourceDayIndex: Int,
        to targetDayIndex: Int,
        in editablePlan: inout MutableWeeklyPlan,
        canEditSource: Bool,
        canEditTarget: Bool
    ) -> Bool {
        // 驗證兩天都可以編輯
        guard canEditSource && canEditTarget else {
            Logger.debug("拖曳失敗：源或目標不可編輯 (源:\(canEditSource), 目標:\(canEditTarget))")
            return false
        }
        
        // 避免自己拖到自己
        guard sourceDayIndex != targetDayIndex else {
            Logger.debug("拖曳失敗：不能拖曳到相同位置")
            return false
        }
        
        // 執行交換
        editablePlan.swapDays(sourceDayIndex, targetDayIndex)
        Logger.debug("成功交換課表：第\(sourceDayIndex+1)天 ↔ 第\(targetDayIndex+1)天")
        
        return true
    }
}

// MARK: - Draggable Training Day

/// 用於拖曳的訓練日包裝  
struct DraggableTrainingDay: Transferable {
    let dayIndex: Int
    let dayName: String
    
    init(dayIndex: Int, day: MutableTrainingDay) {
        self.dayIndex = dayIndex
        self.dayName = day.type.localizedName
    }
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .trainingDay) { trainingDay in
            return Data("\(trainingDay.dayIndex)".utf8)
        } importing: { data in
            guard let string = String(data: data, encoding: .utf8),
                  let dayIndex = Int(string) else {
                throw TransferError.importFailed
            }
            return DraggableTrainingDay(dayIndex: dayIndex, day: MutableTrainingDay(dayIndex: "\(dayIndex)", dayTarget: "", trainingType: "rest"))
        }
    }
}

enum TransferError: Error {
    case importFailed
}

// MARK: - Custom UTType

extension UTType {
    static var trainingDay: UTType {
        UTType(exportedAs: "com.havital.trainingday")
    }
}

// MARK: - Drag and Drop View Modifiers

struct DragDropModifier: ViewModifier {
    let dayIndex: Int
    let day: MutableTrainingDay
    let isEditable: Bool
    let onDragStarted: (Int) -> Void
    let onDropped: (Int, Int) -> Bool

    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var longPressDetected = false
    @State private var isTargeted = false  // 🆕 是否為放置目標

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            // 🆕 頂部插入指示器
            if isTargeted {
                Rectangle()
                    .fill(Color.blue)
                    .frame(height: 4)
                    .cornerRadius(2)
                    .padding(.horizontal, 8)
                    .transition(.opacity)
            }

            content
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .offset(dragOffset)
                .opacity(isDragging ? 0.5 : 1.0)  // 🔧 降低不透明度到 0.5，更明顯
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragging ? Color.blue.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isTargeted ? Color.blue : Color.clear,  // 🆕 目標邊框
<<<<<<< HEAD
                            lineWidth: 3,
                            antialiased: true
=======
                            lineWidth: 3
>>>>>>> dev
                        )
                )
                .animation(.spring(response: 0.3), value: isDragging)
                .animation(.spring(response: 0.2), value: isTargeted)
                .animation(.interactiveSpring(), value: dragOffset)
        }
        .draggable(DraggableTrainingDay(dayIndex: dayIndex, day: day)) {
            // 🔧 改善拖曳預覽
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(weekdayName(for: day.dayIndexInt))
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(day.type.localizedName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()
                }

                Text("拖曳到目標位置")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
            .frame(width: 280)
        }
        .dropDestination(for: DraggableTrainingDay.self) { items, location in
            guard let draggedItem = items.first,
                  isEditable else { return false }

            return onDropped(draggedItem.dayIndex, dayIndex)
        } isTargeted: { isTargeted in
            // 🆕 追蹤是否為拖曳目標
            withAnimation(.spring(response: 0.2)) {
                self.isTargeted = isTargeted
            }
        }
    }

    // 🆕 輔助方法：取得星期名稱
    private func weekdayName(for dayIndex: Int) -> String {
        let weekdays = ["週一", "週二", "週三", "週四", "週五", "週六", "週日"]
        let index = dayIndex - 1  // dayIndex 從 1 開始
        guard index >= 0 && index < weekdays.count else { return "未知" }
        return weekdays[index]
    }
}

// MARK: - Drag Preview

struct DragPreview: View {
    let dayName: String
    let dayIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(weekdayName(for: dayIndex))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(dayName)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(.blue)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Text("拖曳中...")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemBackground))
                .shadow(radius: 8)
        )
        .frame(width: 200)
    }
    
    private func weekdayName(for dayIndex: Int) -> String {
        let weekdays = ["週一", "週二", "週三", "週四", "週五", "週六", "週日"]
        guard dayIndex >= 0 && dayIndex < weekdays.count else { return "未知" }
        return weekdays[dayIndex]
    }
}

// MARK: - Extensions

extension View {
    func dragDropTrainingDay(
        dayIndex: Int,
        day: MutableTrainingDay,
        isEditable: Bool,
        onDragStarted: @escaping (Int) -> Void,
        onDropped: @escaping (Int, Int) -> Bool
    ) -> some View {
        self.modifier(
            DragDropModifier(
                dayIndex: dayIndex,
                day: day,
                isEditable: isEditable,
                onDragStarted: onDragStarted,
                onDropped: onDropped
            )
        )
    }
}

// MARK: - Long Press Drag Gesture (Alternative Implementation)

struct LongPressDragGesture: ViewModifier {
    let dayIndex: Int
    let isEditable: Bool
    let onDragStarted: (Int) -> Void
    let onDropped: (Int, Int) -> Bool
    
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var dragStarted = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .offset(dragOffset)
            .opacity(isDragging ? 0.8 : 1.0)
            .animation(.spring(response: 0.3), value: isDragging)
            .animation(.spring(response: 0.3), value: dragOffset)
            .gesture(
                isEditable ? longPressAndDragGesture : nil
            )
    }
    
    private var longPressAndDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture())
            .onChanged { value in
                switch value {
                case .first(true):
                    // 長按開始
                    if !dragStarted {
                        isDragging = true
                        dragStarted = true
                        onDragStarted(dayIndex)
                        
                        // 振動回饋
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                case .second(true, let drag):
                    // 拖曳過程
                    if let translation = drag?.translation {
                        dragOffset = translation
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                isDragging = false
                dragStarted = false
                dragOffset = .zero
                
                // TODO: 實現拖曳結束後的目標檢測
                // 這裡需要根據最終位置判斷拖曳目標
            }
    }
}

extension View {
    func longPressDrag(
        dayIndex: Int,
        isEditable: Bool,
        onDragStarted: @escaping (Int) -> Void,
        onDropped: @escaping (Int, Int) -> Bool
    ) -> some View {
        self.modifier(
            LongPressDragGesture(
                dayIndex: dayIndex,
                isEditable: isEditable,
                onDragStarted: onDragStarted,
                onDropped: onDropped
            )
        )
    }
}