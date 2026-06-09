import XCTest
@testable import NetworkKitImage

final class ImageCacheTests: XCTestCase {

    private func makeImage() -> (PlatformImage, Data) {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return (image, image.pngData()!)
        #elseif canImport(AppKit)
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        return (image, bitmap.representation(using: .png, properties: [:])!)
        #endif
    }

    func testMemoryStoreAndRetrieve() {
        let cache = ImageCache(directoryName: "Test-\(UUID().uuidString)")
        let (image, data) = makeImage()
        let key = "https://example.com/a.png"

        XCTAssertNil(cache.memoryImage(forKey: key))
        cache.store(image, data: data, forKey: key)
        XCTAssertNotNil(cache.memoryImage(forKey: key))

        cache.clearDisk()
    }

    func testDiskRoundTripAfterMemoryClear() {
        let cache = ImageCache(directoryName: "Test-\(UUID().uuidString)")
        let (image, data) = makeImage()
        let key = "https://example.com/b.png"

        cache.store(image, data: data, forKey: key)
        cache.clearMemory()

        XCTAssertNil(cache.memoryImage(forKey: key))      // gone from memory
        XCTAssertNotNil(cache.image(forKey: key))         // re-loaded from disk

        cache.clearDisk()
        cache.clearMemory()
        XCTAssertNil(cache.image(forKey: key))            // gone from both
    }

    func testCachedImageFacadeReturnsNilForUnknown() {
        XCTAssertNil(WebImageLoader.cachedImage(for: "https://example.com/missing-\(UUID().uuidString).png"))
    }

    func testInvalidURLThrows() async {
        do {
            _ = try await WebImageLoader.image(from: "not a url ::::")
            XCTFail("Expected badURL")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
