import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Encodes images to various formats
public struct ImageEncoder: Sendable {

    public init() {}

    /// Encodes a CGImage to PNG data
    /// - Parameter image: The image to encode
    /// - Returns: PNG data
    /// - Throws: ImageEncoderError if encoding fails
    public func encodePNG(_ image: CGImage) throws -> Data {
        let mutableData = CFDataCreateMutable(nil, 0)!
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageEncoderError.destinationCreationFailed
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageEncoderError.encodingFailed
        }

        return mutableData as Data
    }

    /// Encodes a CGImage to JPEG data
    /// - Parameters:
    ///   - image: The image to encode
    ///   - quality: JPEG quality (0.0 to 1.0)
    /// - Returns: JPEG data
    /// - Throws: ImageEncoderError if encoding fails
    public func encodeJPEG(_ image: CGImage, quality: Double = 0.8) throws -> Data {
        let mutableData = CFDataCreateMutable(nil, 0)!
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageEncoderError.destinationCreationFailed
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ImageEncoderError.encodingFailed
        }

        return mutableData as Data
    }

    /// Encodes image data to base64 string
    /// - Parameter data: The image data
    /// - Returns: Base64 encoded string
    public func encodeBase64(_ data: Data) -> String {
        data.base64EncodedString()
    }

    /// Saves image data to a file
    /// - Parameters:
    ///   - data: The image data
    ///   - path: The file path to save to
    /// - Throws: Error if writing fails
    public func saveToFile(_ data: Data, path: String) throws {
        let url = URL(fileURLWithPath: path)
        try data.write(to: url)
    }
}

// MARK: - Error Types

public enum ImageEncoderError: Error, LocalizedError {
    case destinationCreationFailed
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .destinationCreationFailed:
            return "Failed to create image destination"
        case .encodingFailed:
            return "Failed to encode image"
        }
    }
}
