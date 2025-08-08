import Foundation
import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import Vision

struct QRUtils {
    // Генерация QR для переданного текста
    static func generateQR(from string: String, scale: CGFloat = 12) -> UIImage? {
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        if let cgImage = context.createCGImage(transformed, from: transformed.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    // Извлекает текст QR из изображения через Vision
    static func detectQRCode(in image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else { completion(nil); return }
        let request = VNDetectBarcodesRequest { request, _ in
            let payload = (request.results as? [VNBarcodeObservation])?
                .first(where: { $0.symbology == .qr })?.payloadStringValue
            completion(payload)
        }
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do { try handler.perform([request]) } catch { completion(nil) }
        }
    }
}


