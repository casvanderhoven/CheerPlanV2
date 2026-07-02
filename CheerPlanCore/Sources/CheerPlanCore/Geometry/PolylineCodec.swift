import Foundation

/// Google-style encoded polylines: lat/lon deltas at 1e-5 precision, zigzag +
/// varint, ASCII-63 offset — the compact wire format for course geometry in
/// share links. A simplified marathon fits in roughly 1.5 KB.
public enum PolylineCodec {
    private static let precision = 1e5

    public static func encode(_ coordinates: [Coordinate]) -> String {
        var result = ""
        var previousLatitude = 0
        var previousLongitude = 0
        for coordinate in coordinates {
            let latitude = Int((coordinate.latitude * precision).rounded())
            let longitude = Int((coordinate.longitude * precision).rounded())
            appendValue(latitude - previousLatitude, to: &result)
            appendValue(longitude - previousLongitude, to: &result)
            previousLatitude = latitude
            previousLongitude = longitude
        }
        return result
    }

    /// Nil for malformed input (truncated pairs, characters outside the alphabet).
    public static func decode(_ string: String) -> [Coordinate]? {
        var coordinates: [Coordinate] = []
        let scalars = Array(string.unicodeScalars)
        var index = 0
        var latitude = 0
        var longitude = 0
        while index < scalars.count {
            guard let deltaLatitude = decodeValue(scalars, at: &index),
                  let deltaLongitude = decodeValue(scalars, at: &index) else {
                return nil
            }
            latitude += deltaLatitude
            longitude += deltaLongitude
            coordinates.append(
                Coordinate(
                    latitude: Double(latitude) / precision,
                    longitude: Double(longitude) / precision
                )
            )
        }
        return coordinates
    }

    private static func appendValue(_ value: Int, to result: inout String) {
        var zigzag = value < 0 ? ~(value << 1) : value << 1
        while zigzag >= 0x20 {
            result.append(Character(Unicode.Scalar(UInt8((0x20 | (zigzag & 0x1f)) + 63))))
            zigzag >>= 5
        }
        result.append(Character(Unicode.Scalar(UInt8(zigzag + 63))))
    }

    private static func decodeValue(_ scalars: [Unicode.Scalar], at index: inout Int) -> Int? {
        var result = 0
        var shift = 0
        while index < scalars.count {
            let chunk = Int(scalars[index].value) - 63
            index += 1
            guard chunk >= 0, chunk <= 0x3f, shift < 60 else { return nil }
            result |= (chunk & 0x1f) << shift
            shift += 5
            if chunk < 0x20 {
                return (result & 1) != 0 ? ~(result >> 1) : result >> 1
            }
        }
        return nil
    }
}
