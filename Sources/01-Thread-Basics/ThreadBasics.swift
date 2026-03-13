import Foundation

// ============================================================
// 01. Thread Basics
// 메인 스레드, RunLoop, Race Condition
// ============================================================

// MARK: - 1. Process vs Thread

/// Process: 독립된 메모리 공간을 갖는 실행 단위
/// Thread:  같은 프로세스 내 메모리를 공유하는 실행 흐름

// MARK: - 2. 메인 스레드란?

/// iOS 앱의 메인 스레드는 두 가지 일을 담당합니다:
///   1. UI 렌더링 (UIKit / SwiftUI)
///   2. 사용자 이벤트 처리 (터치, 제스처)
///
/// 메인 스레드가 막히면 → 화면이 얼어붙음 → Watchdog이 앱을 강제 종료

func demonstrateMainThread() {
    print("현재 스레드가 메인인가?", Thread.isMainThread)

    // ❌ Bad: 메인 스레드에서 무거운 작업
    // Thread.sleep(forTimeInterval: 5) // 5초간 UI 완전 정지

    // ✅ Good: 백그라운드에서 무거운 작업
    DispatchQueue.global().async {
        Thread.sleep(forTimeInterval: 5)
        print("백그라운드 작업 완료, 메인인가?", Thread.isMainThread)

        DispatchQueue.main.async {
            print("UI 업데이트는 여기서, 메인인가?", Thread.isMainThread)
        }
    }
}

// MARK: - 3. Race Condition

/// Race Condition: 두 스레드가 같은 데이터를 동시에 읽고 쓸 때 발생
/// 결과가 실행 순서에 따라 달라져서 예측 불가능

class UnsafeCounter {
    var count = 0  // ⚠️ 공유 가변 상태

    func increment() {
        // ❌ 두 스레드가 동시에 실행하면?
        // Thread A: count 읽음 (0)
        // Thread B: count 읽음 (0)
        // Thread A: count = 0 + 1 = 1 씀
        // Thread B: count = 0 + 1 = 1 씀  ← 한 번 증가가 사라짐!
        count += 1
    }
}

func demonstrateRaceCondition() {
    let counter = UnsafeCounter()
    let group = DispatchGroup()

    for _ in 0..<1000 {
        DispatchGroup().enter()
        DispatchQueue.global().async {
            counter.increment()
            group.leave()
        }
    }

    group.notify(queue: .main) {
        // ⚠️ 1000이 아닐 가능성이 높음
        print("최종 count (예측 불가):", counter.count)
    }
}

// MARK: - 4. iOS RunLoop

/// RunLoop: 메인 스레드가 이벤트를 기다리고 처리하는 루프
///
/// while true {
///     let event = waitForEvent()   // 터치, 타이머, 네트워크 등
///     processEvent(event)
/// }
///
/// RunLoop가 막히면 → 이벤트 처리 불가 → UI 응답 없음

// RunLoop 직접 확인
func demonstrateRunLoop() {
    // 타이머는 RunLoop에 등록됨
    let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        print("타이머 실행 — 메인 스레드:", Thread.isMainThread)
    }

    // 5초 후 타이머 해제
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        timer.invalidate()
    }
}
