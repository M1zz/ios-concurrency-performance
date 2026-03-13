# 🚗 iOS 동시성 & 성능 최적화

> **STAGE 6** — iOS 개발 로드맵 · 개발자리

🌐 **GitHub Pages**: [https://m1zz.github.io/ios-concurrency-performance/](https://m1zz.github.io/ios-concurrency-performance/)

부드럽고 빠른 앱을 만드는 데 필요한 동시성(GCD, async/await, Actor), 렌더링 최적화, Combine 학습 레포입니다.

---

## 📌 왜 이 레포인가

S5에서 URLSession을 쓰기 시작하면 **퍼플 경고**가 뜹니다.  
네트워크 요청 중 화면이 얼어붙고, 스크롤 중 프레임 드랍이 생깁니다.  
이 레포는 그 문제들을 직접 재현하고, 올바른 방식으로 고치는 과정을 담고 있습니다.

---

## 🗂 구조

```
ios-concurrency-performance/
├── Sources/
│   ├── 01-Thread-Basics/       # 메인 스레드, RunLoop, Race Condition
│   ├── 02-GCD/                 # DispatchQueue, sync/async, serial/concurrent
│   ├── 03-AsyncAwait/          # async/await, Task, async let, Continuation
│   ├── 04-Actor/               # Actor, MainActor, Sendable
│   ├── 05-Rendering/           # SwiftUI diff, @StateObject vs @ObservedObject
│   ├── 06-ImageOptimization/   # 다운샘플링, NSCache, Prefetching
│   └── 07-Combine/             # Publisher, debounce, combineLatest, flatMap
├── Playgrounds/                # Xcode Playground 파일들
└── Resources/                  # 다이어그램, 참고 자료
```

---

## 📚 학습 순서

### 6-1 ⚙️ 메인 스레드와 동시성

| # | 파일 | 핵심 개념 |
|---|------|-----------|
| 1 | `01-Thread-Basics/ThreadBasics.swift` | Process vs Thread, RunLoop, Race Condition |
| 2 | `02-GCD/GCDExamples.swift` | DispatchQueue, sync/async, serial/concurrent |
| 3 | `02-GCD/DispatchGroupExample.swift` | DispatchGroup, Semaphore, Barrier |
| 4 | `03-AsyncAwait/AsyncAwaitBasics.swift` | async/await, Task, async let |
| 5 | `03-AsyncAwait/ContinuationExample.swift` | withCheckedContinuation — 콜백 → async 변환 |
| 6 | `04-Actor/ActorExample.swift` | Actor, MainActor, Sendable |

### 6-2 🎞 렌더링 성능 최적화

| # | 파일 | 핵심 개념 |
|---|------|-----------|
| 7 | `05-Rendering/SwiftUIRendering.swift` | diff, Equatable, identity/lifetime/dependency |
| 8 | `06-ImageOptimization/Downsampling.swift` | ImageIO 다운샘플링 (48MB → 0.04MB) |
| 9 | `06-ImageOptimization/ImageCache.swift` | NSCache, Prefetching |

### 6-3 🔄 Combine

| # | 파일 | 핵심 개념 |
|---|------|-----------|
| 10 | `07-Combine/CombineBasics.swift` | Publisher, Subscriber, Operator |
| 11 | `07-Combine/SearchDebounce.swift` | debounce, removeDuplicates |
| 12 | `07-Combine/FormValidation.swift` | combineLatest — 폼 유효성 검사 |
| 13 | `07-Combine/NetworkChaining.swift` | flatMap + URLSession, 에러 처리 |

---

## 🧪 핵심 Before / After

### 메인 스레드

```swift
// ❌ Before — 퍼플 경고, 크래시 가능
URLSession.shared.dataTask(with: url) { data, _, _ in
    self.imageView.image = UIImage(data: data!) // 백그라운드 스레드!
}.resume()

// ✅ After — async/await + @MainActor
func loadImage() async throws {
    let (data, _) = try await URLSession.shared.data(from: url)
    await MainActor.run {
        self.imageView.image = UIImage(data: data)
    }
}
```

### 이미지 최적화

```swift
// ❌ Before — 48MB
let image = UIImage(data: try! Data(contentsOf: url))

// ✅ After — 0.04MB
let image = downsample(imageAt: url, to: CGSize(width: 100, height: 100))
```

### Combine debounce

```swift
// ❌ Before — 매 글자마다 4번 API 호출
textField.addTarget(self, action: #selector(search), for: .editingChanged)

// ✅ After — 입력 멈춘 후 0.3초 뒤 1번만
$searchText
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .removeDuplicates()
    .flatMap { APIClient.search(query: $0) }
    .sink { self.results = $0 }
    .store(in: &cancellables)
```

---

## ✅ 이 단계를 마치면

- [x] `async/await`로 비동기 코드를 동기처럼 작성할 수 있다
- [x] `Actor`로 Data Race를 컴파일러 수준에서 방지한다
- [x] `ImageIO`로 이미지 메모리를 1200배 줄일 수 있다
- [x] `Combine`으로 복잡한 이벤트 흐름을 선언적으로 처리한다
- [x] 사용자가 체감하는 앱 품질이 달라진다

---

## ⚠️ 아직 남은 것

> 자동차를 몰 수 있습니다. 하지만 보험도 없고, 정비소도 없습니다.

테스트가 없어서 배포할 때마다 긴장합니다.  
→ **STAGE 7** (테스트 & CI/CD)에서 해결합니다.

---

## 📎 참고 자료

- [Swift Concurrency — Apple Developer](https://developer.apple.com/swift/concurrency/)
- [WWDC21: Meet async/await in Swift](https://developer.apple.com/videos/play/wwdc2021/10132/)
- [WWDC21: Explore structured concurrency in Swift](https://developer.apple.com/videos/play/wwdc2021/10134/)
- [WWDC21: Protect mutable state with Swift actors](https://developer.apple.com/videos/play/wwdc2021/10133/)
- [WWDC18: Image and Graphics Best Practices](https://developer.apple.com/videos/play/wwdc2018/219/)
- [Combine — Apple Developer](https://developer.apple.com/documentation/combine)

---

<div align="center">
  <sub>개발자리 · 10년차 iOS 개발자의 실험일지</sub>
</div>
