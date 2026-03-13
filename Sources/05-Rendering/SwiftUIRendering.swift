import SwiftUI
import Combine

// ============================================================
// 05. SwiftUI 렌더링 최적화
// 불필요한 재렌더링 막기
// ============================================================

// MARK: - 1. SwiftUI diff — 언제 View가 다시 그려지는가

/// SwiftUI는 상태(State)가 변경될 때 body를 재계산합니다.
/// 문제: 부모의 상태 변경이 자식 View도 재렌더링시킬 수 있습니다.

// ❌ Bad: 전체 리스트가 매번 재렌더링
struct BadParentView: View {
    @State private var counter = 0
    let items = Array(0..<1000)

    var body: some View {
        VStack {
            Button("Tap: \(counter)") { counter += 1 }  // counter 변경 시
            List(items, id: \.self) { item in
                HeavyRowView(item: item)  // 1000개 모두 재렌더링 💀
            }
        }
    }
}

// ✅ Good: 상태를 분리하여 영향 범위 최소화
struct GoodParentView: View {
    let items = Array(0..<1000)

    var body: some View {
        VStack {
            CounterView()          // 독립적인 상태
            List(items, id: \.self) { item in
                HeavyRowView(item: item)  // Counter 변경 시 영향 없음 ✅
            }
        }
    }
}

struct CounterView: View {
    @State private var counter = 0
    var body: some View {
        Button("Tap: \(counter)") { counter += 1 }
    }
}

// MARK: - 2. Equatable — 같은 값이면 렌더링 스킵

// ❌ Equatable 없음 — props가 같아도 항상 재렌더링
struct UserRowWithoutEquatable: View {
    let user: User

    var body: some View {
        HStack {
            Text(user.name)
            Text(user.email)
        }
    }
}

// ✅ Equatable 채택 — 값이 같으면 body 재계산 스킵
struct UserRow: View, Equatable {
    let user: User

    static func == (lhs: UserRow, rhs: UserRow) -> Bool {
        lhs.user.id == rhs.user.id &&
        lhs.user.name == rhs.user.name
    }

    var body: some View {
        HStack {
            Text(user.name)
            Text(user.email)
        }
    }
}

// EquatableView로 래핑
struct OptimizedList: View {
    let users: [User]

    var body: some View {
        List(users) { user in
            UserRow(user: user).equatable()  // Equatable이면 스킵
        }
    }
}

// MARK: - 3. @StateObject vs @ObservedObject

/// @StateObject:
///   - View가 소유 (ownership)
///   - View 생명주기와 함께 생성/소멸
///   - 부모 View가 재렌더링돼도 유지됨 ✅
///
/// @ObservedObject:
///   - View가 관찰만 함 (외부에서 주입)
///   - 부모 View 재렌더링 시 새로 주입될 수 있음 ⚠️

class TimerViewModel: ObservableObject {
    @Published var count = 0
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.count += 1
        }
    }

    deinit {
        timer?.invalidate()
        print("TimerViewModel 해제됨")
    }
}

// ❌ Bad: @ObservedObject — 부모 재렌더링 시 ViewModel 초기화될 수 있음
struct BadTimerView: View {
    @ObservedObject var viewModel = TimerViewModel()  // ⚠️

    var body: some View {
        Text("Count: \(viewModel.count)")
    }
}

// ✅ Good: @StateObject — View가 소유, 안전하게 유지
struct GoodTimerView: View {
    @StateObject private var viewModel = TimerViewModel()  // ✅

    var body: some View {
        Text("Count: \(viewModel.count)")
    }
}

// MARK: - 4. LazyVStack vs List

/// LazyVStack:
///   - 화면에 보이는 것만 렌더링 (Lazy)
///   - ScrollView 안에 사용
///   - 완전한 커스텀 가능
///   - 셀 재사용 없음 (스크롤 시 재생성)
///
/// List:
///   - UITableView 기반 — 셀 재사용 (효율적)
///   - 자동 separator, swipeActions 등 제공
///   - 커스터마이징 제한적
///   - 대량 데이터에 더 효율적

struct LazyVStackExample: View {
    let items = Array(0..<10000)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    ItemView(id: item)  // 화면 밖은 렌더링 안 함
                }
            }
        }
    }
}

// MARK: - 5. SwiftUI 3원칙: identity, lifetime, dependency

/// 1. Identity (식별성)
///    - View가 같은 View인지 SwiftUI가 판단하는 기준
///    - ForEach의 id, .id() modifier
///
/// 2. Lifetime (생명주기)
///    - identity가 유지되는 동안 @State, @StateObject 보존
///    - identity 변경 시 → 초기화
///
/// 3. Dependency (의존성)
///    - View가 어떤 데이터에 의존하는가
///    - 의존 데이터 변경 시 → body 재실행

// Identity 예시
struct IdentityExample: View {
    @State private var showProfile = false

    var body: some View {
        if showProfile {
            // ✅ 같은 identity — State 유지
            UserProfileView()
        } else {
            UserProfileView()
        }

        // vs

        // ⚠️ AnyView 사용 시 identity 손실 → State 초기화 가능
        // AnyView(showProfile ? UserProfileView() : UserProfileView())
    }
}

// MARK: - Supporting Types
struct User: Identifiable {
    let id: String
    let name: String
    let email: String
}

struct HeavyRowView: View {
    let item: Int
    var body: some View { Text("Item \(item)") }
}

struct ItemView: View {
    let id: Int
    var body: some View { Text("Item \(id)") }
}

struct UserProfileView: View {
    @State private var text = ""
    var body: some View { TextField("입력", text: $text) }
}
