import UIKit
import ImageIO

// ============================================================
// 06. 이미지 최적화
// 다운샘플링, NSCache, Prefetching
// ============================================================

// MARK: - 1. 문제: 원본 이미지 그대로 로드

/// 4000×3000 이미지를 100×100 썸네일로 보여줄 때
///
/// ❌ UIImage(data:) 사용
///   → 전체 픽셀 디코딩: 4000 × 3000 × 4bytes = 48MB
///
/// ✅ ImageIO 다운샘플링
///   → 100 × 100 × 4bytes = 0.04MB
///   → 1200배 차이!

// MARK: - 2. 다운샘플링 구현

func downsample(imageAt url: URL, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {

    // 1. 이미지 소스 생성 (메모리에 올리지 않음)
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else {
        return nil
    }

    // 2. 최대 픽셀 크기 계산
    let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale

    // 3. 썸네일 옵션 설정
    let downsampleOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,       // 이 크기만 캐시
        kCGImageSourceCreateThumbnailWithTransform: true, // 회전 정보 반영
        kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
    ]

    // 4. 필요한 크기만 디코딩
    guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(
        imageSource, 0, downsampleOptions as CFDictionary
    ) else {
        return nil
    }

    return UIImage(cgImage: downsampledImage)
}

// Data에서 바로 다운샘플링
func downsample(data: Data, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
        return nil
    }

    let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
    let downsampleOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
    ]

    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
        imageSource, 0, downsampleOptions as CFDictionary
    ) else {
        return nil
    }

    return UIImage(cgImage: cgImage)
}

// MARK: - 3. NSCache — 자동 해제 이미지 캐시

/// NSCache:
///   - 메모리 압박 시 자동으로 항목 삭제
///   - 스레드 안전 (thread-safe)
///   - NSDictionary와 달리 키를 복사하지 않음

final class ImageCache {
    static let shared = ImageCache()
    private init() {}

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100          // 최대 100개 이미지
        cache.totalCostLimit = 50 * 1024 * 1024  // 최대 50MB
        return cache
    }()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func store(_ image: UIImage, for url: URL) {
        // cost: 이미지 바이트 크기로 설정
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }

    func removeImage(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }
}

// MARK: - 4. 캐시 + 다운샘플링 통합 로더

final class ThumbnailLoader {
    static let shared = ThumbnailLoader()
    private init() {}

    private let cache = ImageCache.shared

    func loadThumbnail(from url: URL,
                       targetSize: CGSize,
                       completion: @escaping (UIImage?) -> Void) {

        // 1. 캐시 확인
        if let cached = cache.image(for: url) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        // 2. 백그라운드에서 다운로드 + 다운샘플링
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = try? Data(contentsOf: url) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // 다운샘플링 (메모리 효율)
            let thumbnail = downsample(data: data, to: targetSize)

            // 캐시 저장
            if let thumbnail {
                self.cache.store(thumbnail, for: url)
            }

            // 메인 스레드에서 콜백
            DispatchQueue.main.async { completion(thumbnail) }
        }
    }

    // async/await 버전
    func loadThumbnail(from url: URL, targetSize: CGSize) async -> UIImage? {
        if let cached = cache.image(for: url) { return cached }

        return await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            let thumbnail = downsample(data: data, to: targetSize)
            if let thumbnail { self.cache.store(thumbnail, for: url) }
            return thumbnail
        }.value
    }
}

// MARK: - 5. 이미지 포맷 비교

/// PNG:  무손실 압축, 투명도 지원, 파일 큼
/// JPEG: 손실 압축, 사진에 적합, 파일 작음
/// HEIC: Apple 포맷, JPEG 대비 2배 압축, iOS 11+
/// WebP: Google 포맷, JPEG 대비 25~34% 작음, iOS 14+

extension UIImage {
    func heicData(compressionQuality: CGFloat = 0.8) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                  mutableData, AVFileType.heic as CFString, 1, nil),
              let cgImage = cgImage
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}

// MARK: - Stub
import AVFoundation
