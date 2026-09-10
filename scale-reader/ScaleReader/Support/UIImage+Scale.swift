import UIKit

extension UIImage {
    /// 等比缩放到最长边不超过 maxDimension，用于控制上传体积。
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

    /// AI 请求用 JPEG 数据。
    func jpegDataForAI() -> Data? {
        downscaled(maxDimension: 1600).jpegData(compressionQuality: 0.72)
    }
}
