import Foundation

// ============================================================
// 03. async/await — 콜백 지옥 탈출
// ============================================================

// MARK: - 1. 콜백 지옥 vs async/await

// ❌ Before: 콜백 중첩 — "Pyramid of Doom"
func fetchUserWithCallbacks(id: String,
                             completion: @escaping (Result<String, Error>) -> Void) {
    fetchUser(id: id) { userResult in
        switch userResult {
        case .failure(let e): completion(.failure(e))
        case .success(let user):
            fetchPosts(userId: user) { postsResult in
                switch postsResult {
                case .failure(let e): completion(.failure(e))
                case .success(let posts):
                    fetchComments(postId: posts) { commentsResult in
                        switch commentsResult {
                        case .failure(let e): completion(.failure(e))
                        case .success(let comments):
                            completion(.success(comments))
                        }
                    }
                }
            }
        }
    }
}

// ✅ After: async/await — 선형 코드로
func fetchUserWithAsync(id: String) async throws -> String {
    let user    = try await fetchUser(id: id)
    let posts   = try await fetchPosts(userId: user)
    let comments = try await fetchComments(postId: posts)
    return comments
}

// MARK: - 2. await — 기다리지만 스레드는 안 막음

/// await를 만나면:
///   1. 현재 Task는 일시 정지 (suspend)
///   2. 스레드는 반환 → 다른 Task가 이 스레드를 사용 가능
///   3. 작업 완료 → Task 재개 (resume)
///
/// DispatchQueue.sync와의 차이:
///   - sync: 스레드를 블로킹 (스레드 낭비)
///   - await: 스레드를 반납 (효율적)

// MARK: - 3. Task — 비동기 작업 생명주기

func demonstrateTasks() {
    // Task 생성 — 비동기 컨텍스트 진입점
    Task {
        let result = try await fetchUserWithAsync(id: "123")
        print(result)
    }

    // Task 취소
    let task = Task {
        for i in 0..<100 {
            try Task.checkCancellation()  // 취소 확인
            print("작업 중:", i)
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    // 1초 후 취소
    Task {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        task.cancel()
        print("Task 취소됨")
    }
}

// MARK: - 4. async let — 병렬 실행

func fetchDashboard() async throws {
    // ❌ 순차 실행 — user 완료 후 posts 시작 (느림)
    let user1  = try await fetchUser(id: "1")
    let posts1 = try await fetchPosts(userId: user1)
    print("순차:", user1, posts1)

    // ✅ async let — 병렬 실행 (빠름)
    async let user  = fetchUser(id: "1")
    async let posts = fetchPosts(userId: "1")

    // 두 작업이 동시에 시작됨
    // await으로 결과를 모을 때 기다림
    let (u, p) = try await (user, posts)
    print("병렬:", u, p)
}

// MARK: - 5. withCheckedContinuation — 콜백 → async 변환

/// 기존 콜백 기반 API를 async로 래핑할 때 사용

// 기존 콜백 API (변경 불가라고 가정)
func legacyFetchUser(id: String, completion: @escaping (String?, Error?) -> Void) {
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
        completion("User-\(id)", nil)
    }
}

// ✅ async 버전으로 래핑
func fetchUser(id: String) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        legacyFetchUser(id: id) { user, error in
            if let error {
                continuation.resume(throwing: error)
            } else if let user {
                continuation.resume(returning: user)
            }
        }
    }
}

// MARK: - Stubs (컴파일용)
private func fetchPosts(userId: String) async throws -> String { "Posts" }
private func fetchComments(postId: String) async throws -> String { "Comments" }
private func fetchUser(id: String, completion: @escaping (Result<String, Error>) -> Void) {}
private func fetchPosts(userId: String, completion: @escaping (Result<String, Error>) -> Void) {}
private func fetchComments(postId: String, completion: @escaping (Result<String, Error>) -> Void) {}
