import Foundation

// ============================================================
// 04. Actor — Data Race를 컴파일러가 막는 방법
// ============================================================

// MARK: - 1. Actor

/// Actor: 내부 상태에 대한 직렬 접근을 보장하는 참조 타입
/// - class와 비슷하지만, 한 번에 하나의 코드만 내부 상태에 접근 가능
/// - 컴파일 타임에 Data Race를 잡아줌

// ❌ Class — Data Race 발생 가능
class UnsafeCounter {
    var count = 0
    func increment() { count += 1 }  // 여러 스레드가 동시에 접근 → 레이스 컨디션
}

// ✅ Actor — 컴파일러가 보호
actor SafeCounter {
    var count = 0

    func increment() {
        count += 1  // Actor 내부: 직렬 실행 보장
    }

    func getCount() -> Int {
        count
    }
}

func demonstrateActor() async {
    let counter = SafeCounter()

    // await 필요 — actor 접근은 비동기
    await counter.increment()
    let count = await counter.getCount()
    print("안전한 count:", count)

    // 1000개 동시 접근 — 모두 안전
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<1000 {
            group.addTask {
                await counter.increment()
            }
        }
    }

    print("최종 count (반드시 1000):", await counter.getCount())
}

// MARK: - 2. Actor와 nonisolated

actor UserCache {
    private var cache: [String: String] = [:]

    // Actor-isolated: await 필요
    func store(user: String, for id: String) {
        cache[id] = user
    }

    func fetch(id: String) -> String? {
        cache[id]
    }

    // nonisolated: await 불필요 — 상태에 접근하지 않음
    nonisolated func cacheDescription() -> String {
        "UserCache — thread-safe actor"
    }
}

// MARK: - 3. @MainActor — UI 업데이트 안전하게

/// @MainActor: 메인 스레드에서 실행을 보장하는 글로벌 Actor

@MainActor
class ViewModel: ObservableObject {
    @Published var users: [String] = []
    @Published var isLoading = false

    func loadUsers() async {
        isLoading = true  // @MainActor → 메인 스레드 보장

        do {
            // 백그라운드에서 네트워크 요청
            let fetched = try await fetchUsersFromNetwork()

            // @MainActor 클래스이므로 여기도 메인 스레드
            users = fetched
        } catch {
            print("에러:", error)
        }

        isLoading = false
    }
}

// @MainActor를 함수에만 적용
func updateUI() async {
    await MainActor.run {
        print("메인 스레드에서 UI 업데이트:", Thread.isMainThread)
    }
}

// MARK: - 4. Sendable — 스레드 안전 타입 마킹

/// Sendable: 다른 동시성 도메인(스레드)으로 안전하게 전달 가능한 타입
/// - Value types (struct, enum): 자동으로 Sendable
/// - Actor: Sendable
/// - Class: @unchecked Sendable 또는 명시적 준수 필요

// ✅ Struct — 값 타입이므로 자동 Sendable
struct UserData: Sendable {
    let id: String
    let name: String
}

// ✅ 불변 클래스 — Sendable 선언 가능
final class ImmutableConfig: Sendable {
    let apiKey: String
    init(key: String) { self.apiKey = key }
}

// ⚠️ 가변 클래스 — @unchecked Sendable (직접 책임)
final class MutableConfig: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: String = ""

    var value: String {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

// MARK: - 5. GCD vs async/await 비교

/// 같은 문제를 두 방식으로

// GCD 방식
func loadImageGCD(url: URL, completion: @escaping (Data?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let data = try? Data(contentsOf: url)
        DispatchQueue.main.async {
            completion(data)
        }
    }
}

// async/await 방식 (더 명확)
func loadImageAsync(url: URL) async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
    // @MainActor 컨텍스트에서 호출하면 UI 업데이트도 안전
}

// MARK: - Stubs
private func fetchUsersFromNetwork() async throws -> [String] { ["User1", "User2"] }
