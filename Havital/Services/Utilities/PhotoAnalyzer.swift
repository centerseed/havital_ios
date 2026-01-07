import UIKit
import SwiftUI
import CoreImage
import Vision

/// 照片分析器 - 用於分析照片亮度、構圖並推薦最佳分享卡版型
class PhotoAnalyzer {

    // MARK: - Public Methods

    /// 分析照片並推薦版型
    func analyze(_ image: UIImage) -> PhotoAnalysisResult {
        let brightness = calculateBrightness(image)
        let subjectPosition = detectSubjectPosition(image)
        let dominantColors = extractDominantColors(image)

        // 版型推薦邏輯
        let layout = suggestLayout(brightness: brightness, subjectPosition: subjectPosition)

        // 文字顏色推薦
        let textColor: Color = brightness > 0.5 ? .black : .white

        // 配色方案推薦
        let colorScheme: ShareCardColorScheme
        switch layout {
        case .top:
            colorScheme = .topGradient
        case .bottom, .side:
            colorScheme = brightness > 0.5 ? .light : .default
        case .auto:
            colorScheme = .default
        }

        return PhotoAnalysisResult(
            brightness: brightness,
            subjectPosition: subjectPosition,
            dominantColors: dominantColors,
            suggestedLayout: layout,
            suggestedTextColor: textColor,
            suggestedColorScheme: colorScheme
        )
    }

    // MARK: - Private Methods

    /// 計算照片平均亮度 (0-1)
    private func calculateBrightness(_ image: UIImage) -> Double {
        guard let ciImage = CIImage(image: image) else {
            print("⚠️ [PhotoAnalyzer] 無法轉換為 CIImage,使用預設亮度")
            return 0.5
        }

        let extent = ciImage.extent

        // 使用 CIAreaAverage 濾鏡計算平均顏色
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ]) else {
            print("⚠️ [PhotoAnalyzer] 無法創建 CIAreaAverage 濾鏡")
            return 0.5
        }

        guard let outputImage = filter.outputImage else {
            print("⚠️ [PhotoAnalyzer] 濾鏡輸出為空")
            return 0.5
        }

        // 將輸出圖像轉換為 bitmap
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        // 計算亮度 (使用相對亮度公式)
        let red = Double(bitmap[0]) / 255.0
        let green = Double(bitmap[1]) / 255.0
        let blue = Double(bitmap[2]) / 255.0

        // 相對亮度公式: Y = 0.299R + 0.587G + 0.114B
        let brightness = 0.299 * red + 0.587 * green + 0.114 * blue

        print("📊 [PhotoAnalyzer] 照片亮度: \(String(format: "%.2f", brightness))")

        return brightness
    }

    /// 偵測照片中的主體位置
    private func detectSubjectPosition(_ image: UIImage) -> SubjectPosition {
        guard let cgImage = image.cgImage else {
            print("⚠️ [PhotoAnalyzer] 無法轉換為 CGImage,使用預設位置")
            return .center
        }

        // 使用 Vision 框架偵測人臉
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            if let observations = request.results, !observations.isEmpty {
                // 找到人臉,根據人臉位置判斷主體位置
                let firstFace = observations[0]
                let boundingBox = firstFace.boundingBox

                // Vision 框架的座標系統: 原點在左下角
                let centerY = boundingBox.midY
                let centerX = boundingBox.midX

                print("📊 [PhotoAnalyzer] 偵測到人臉位置: (\(String(format: "%.2f", centerX)), \(String(format: "%.2f", centerY)))")

                // 判斷主體位置
                if centerY > 0.6 {
                    return .top  // 人臉在上方
                } else if centerY < 0.4 {
                    return .bottom  // 人臉在下方
                } else if centerX < 0.4 {
                    return .left  // 人臉在左側
                } else if centerX > 0.6 {
                    return .right  // 人臉在右側
                } else {
                    return .center  // 人臉在中央
                }
            }
        } catch {
            print("⚠️ [PhotoAnalyzer] 人臉偵測失敗: \(error.localizedDescription)")
        }

        // 如果沒有偵測到人臉,使用顯著性分析
        return detectSaliency(cgImage)
    }

    /// 使用顯著性分析偵測主體位置
    private func detectSaliency(_ cgImage: CGImage) -> SubjectPosition {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            if let observation = request.results?.first as? VNSaliencyImageObservation {
                // 分析顯著區域的中心點
                let salientObjects = observation.salientObjects ?? []

                if !salientObjects.isEmpty {
                    let centerY = salientObjects.map { $0.boundingBox.midY }.reduce(0, +) / Double(salientObjects.count)
                    let centerX = salientObjects.map { $0.boundingBox.midX }.reduce(0, +) / Double(salientObjects.count)

                    print("📊 [PhotoAnalyzer] 顯著性中心: (\(String(format: "%.2f", centerX)), \(String(format: "%.2f", centerY)))")

                    if centerY > 0.6 {
                        return .top
                    } else if centerY < 0.4 {
                        return .bottom
                    } else if centerX < 0.4 {
                        return .left
                    } else if centerX > 0.6 {
                        return .right
                    } else {
                        return .center
                    }
                }
            }
        } catch {
            print("⚠️ [PhotoAnalyzer] 顯著性分析失敗: \(error.localizedDescription)")
        }

        // 預設返回中央
        print("📊 [PhotoAnalyzer] 使用預設位置: center")
        return .center
    }

    /// 提取主要顏色
    private func extractDominantColors(_ image: UIImage) -> [Color] {
        // TODO: 實現 K-Means 顏色聚類
        // 目前返回空數組,後續可實現更複雜的顏色分析
        return []
    }

    /// 根據亮度和主體位置推薦版型
    private func suggestLayout(brightness: Double, subjectPosition: SubjectPosition) -> ShareCardLayoutMode {
        print("📊 [PhotoAnalyzer] 亮度: \(String(format: "%.2f", brightness)), 主體位置: \(subjectPosition)")

        switch (brightness, subjectPosition) {
        case (0.7...1.0, .bottom):
            // 亮背景 + 人物偏下 → 底部橫條
            print("📊 [PhotoAnalyzer] 推薦版型: bottom (亮背景 + 主體偏下)")
            return .bottom

        case (0.3...0.7, .left), (0.3...0.7, .right):
            // 中等亮度 + 人物偏側 → 側邊浮層
            print("📊 [PhotoAnalyzer] 推薦版型: side (中等亮度 + 主體偏側)")
            return .side

        case (0.0...0.3, _):
            // 暗背景 → 頂部置中
            print("📊 [PhotoAnalyzer] 推薦版型: top (暗背景)")
            return .top

        default:
            // 預設使用底部橫條
            print("📊 [PhotoAnalyzer] 推薦版型: bottom (預設)")
            return .bottom
        }
    }
}
