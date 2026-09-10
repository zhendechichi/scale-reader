import UIKit

extension UIImage {
    /// 等比缩放到最长边不超过 maxDimension，用于控制上传体积。
    /// 注意：分辨率直接影响小数点等细节的识别率，不要调得太低。
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return self }
        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// AI 请求用 JPEG 数据：保留较高分辨率与画质，便于辨认小数点。
    func jpegDataForAI() -> Data? {
        downscaled(maxDimension: 2000).jpegData(compressionQuality: 0.85)
    }
}
