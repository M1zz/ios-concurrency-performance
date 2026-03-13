import Foundation
import Combine

// ============================================================
// 07. Combine — 반응형 프로그래밍
// Publisher · Subscriber · Operator
// ============================================================

// MARK: - 1. 핵심 개념

/// Publisher:  시간에 따라 값을 방출하는 스트림
/// Subscriber: 값을 받아서 처리
/// Operator:   스트림을 변환/필터/조합
///
/// Publisher --[값]--> Operator --[변환된 값]--> Subscriber

// MARK: - 2. @Published — 프로퍼티 변경을 Publisher로

class SearchViewModel: ObservableObject {
    @Published var searchText = ""        // Publisher 자동 생성
    @Published var results: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSearchPipeline()
    }

    private func setupSearchPipeline() {
        $searchText  // Published<String>.Publisher
            // 타이핑 멈춘 후 0.3초 뒤에만 이벤트 통과
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)

            // 이전 값과 같으면 무시 ("한글" → "한글" 연속 입력 방지)
            .removeDuplicates()

            // 빈 문자열 무시
            .filter { !$0.isEmpty }

            // 로딩 상태 설정 (side effect)
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isLoading = true
                self?.errorMessage = nil
            })

            // 비동기 네트워크 요청 — flatMap으로 체이닝
            // switchToLatest: 새 검색어 입력 시 이전 요청 자동 취소
            .flatMap { [weak self] query -> AnyPublisher<[String], Never> in
                guard let self else { return Just([]).eraseToAnyPublisher() }
                return self.search(query: query)
            }

            // 결과를 메인 스레드에서 받기
            .receive(on: RunLoop.main)

            // 구독: 결과를 results에 저장
            .sink { [weak self] searchResults in
                self?.isLoading = false
                self?.results = searchResults
            }
            .store(in: &cancellables)  // 구독 생명주기 관리
    }

    private func search(query: String) -> AnyPublisher<[String], Never> {
        // 실제 구현에서는 URLSession 사용
        Just(["결과: \(query) 1", "결과: \(query) 2"])
            .delay(for: .milliseconds(300), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
}

// MARK: - 3. 폼 유효성 검사 — combineLatest

class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""

    // 여러 Publisher를 조합하여 버튼 활성화 여부 계산
    @Published var isFormValid = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        Publishers.CombineLatest3($email, $password, $confirmPassword)
            .map { email, password, confirm in
                email.contains("@") &&           // 이메일 형식
                password.count >= 8 &&           // 비밀번호 8자 이상
                password == confirm              // 비밀번호 일치
            }
            .assign(to: &$isFormValid)           // .assign: sink 대신 직접 프로퍼티에
    }
}

// MARK: - 4. 네트워크 체이닝 — flatMap + URLSession

struct Post: Codable, Identifiable {
    let id: Int
    let title: String
    let userId: Int
}

struct User: Codable {
    let id: Int
    let name: String
}

class NetworkViewModel: ObservableObject {
    @Published var postWithAuthor: String = ""
    private var cancellables = Set<AnyCancellable>()

    func loadPostWithAuthor(postId: Int) {
        // 1. Post 가져오기
        fetchPost(id: postId)
            // 2. Post의 userId로 User 가져오기 (체이닝)
            .flatMap { post in
                self.fetchUser(id: post.userId)
                    .map { user in "\(post.title) — by \(user.name)" }
            }
            // 에러 처리
            .catch { error -> Just<String> in
                print("에러:", error)
                return Just("로드 실패")
            }
            .receive(on: RunLoop.main)
            .assign(to: &$postWithAuthor)
    }

    private func fetchPost(id: Int) -> AnyPublisher<Post, Error> {
        let url = URL(string: "https://jsonplaceholder.typicode.com/posts/\(id)")!
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: Post.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    private func fetchUser(id: Int) -> AnyPublisher<User, Error> {
        let url = URL(string: "https://jsonplaceholder.typicode.com/users/\(id)")!
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: User.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

// MARK: - 5. 에러 처리

func demonstrateErrorHandling() {
    let publisher = URLSession.shared
        .dataTaskPublisher(for: URL(string: "https://api.example.com/data")!)
        .map(\.data)

    // catch: 에러를 다른 Publisher로 교체
    publisher
        .catch { _ in Just(Data()) }
        .sink { _ in }
        .cancel()

    // retry: N번 재시도
    publisher
        .retry(3)
        .catch { _ in Just(Data()) }
        .sink { _ in }
        .cancel()

    // replaceError: 에러를 기본값으로 교체
    publisher
        .replaceError(with: Data())
        .sink { _ in }
        .cancel()
}

// MARK: - 6. AnyCancellable — 구독 수명 관리

/// AnyCancellable: 구독을 취소할 수 있는 토큰
///
/// 메모리 누수 방지:
/// - Set에 store → ViewModel이 해제될 때 자동 구독 취소
/// - 명시적 cancel() 호출 가능

class ExampleViewModel {
    private var cancellables = Set<AnyCancellable>()

    // ✅ Set에 저장 — ViewModel 해제 시 자동 취소
    func subscribe() {
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { date in print("Tick:", date) }
            .store(in: &cancellables)   // 핵심!
    }

    // 명시적 취소
    func unsubscribe() {
        cancellables.removeAll()
    }
}
