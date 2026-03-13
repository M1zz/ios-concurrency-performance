import Foundation

// ============================================================
// 02. GCD (Grand Central Dispatch)
// DispatchQueue · sync/async · serial/concurrent
// ============================================================

// MARK: - 1. DispatchQueue 종류

func demonstrateQueues() {

    // 1️⃣ Main Queue — UI 전담, serial
    DispatchQueue.main.async {
        print("메인 큐:", Thread.isMainThread)
    }

    // 2️⃣ Global Queue — 백그라운드, concurrent
    //    QoS(Quality of Service)로 우선순위 지정
    DispatchQueue.global(qos: .userInitiated).async {  // 즉각 결과 필요
        print("userInitiated")
    }
    DispatchQueue.global(qos: .utility).async {         // 긴 작업, 진행 표시 가능
        print("utility")
    }
    DispatchQueue.global(qos: .background).async {      // 사용자 안 봄, 에너지 절약
        print("background")
    }

    // 3️⃣ Custom Queue — serial 또는 concurrent 직접 생성
    let serialQueue = DispatchQueue(label: "com.devjaeri.serial")
    let concurrentQueue = DispatchQueue(label: "com.devjaeri.concurrent",
                                        attributes: .concurrent)
    _ = serialQueue
    _ = concurrentQueue
}

// MARK: - 2. sync vs async

/// sync:  현재 스레드를 블로킹 — 작업 완료까지 기다림
/// async: 현재 스레드 블로킹 없이 작업 예약 후 즉시 반환

func demonstrateSyncAsync() {
    let queue = DispatchQueue(label: "com.devjaeri.example")

    print("A")

    // async: 즉시 반환, 나중에 실행
    queue.async {
        Thread.sleep(forTimeInterval: 0.1)
        print("B (async)")
    }

    print("C")  // B보다 먼저 출력됨: A → C → B

    // sync: 블로킹, 완료 후 진행
    queue.sync {
        Thread.sleep(forTimeInterval: 0.1)
        print("D (sync)")
    }

    print("E")  // D 완료 후: D → E
}

// MARK: - 3. serial vs concurrent

/// serial:     한 번에 하나씩 순서대로 실행
/// concurrent: 동시에 여러 개 실행 (완료 순서 보장 안 됨)

func demonstrateSerialVsConcurrent() {
    let serial = DispatchQueue(label: "serial")
    let concurrent = DispatchQueue(label: "concurrent", attributes: .concurrent)

    // Serial: 1 → 2 → 3 순서 보장
    for i in 1...3 {
        serial.async {
            Thread.sleep(forTimeInterval: Double.random(in: 0.1...0.3))
            print("Serial \(i)")  // 반드시 1, 2, 3 순서
        }
    }

    // Concurrent: 순서 랜덤
    for i in 1...3 {
        concurrent.async {
            Thread.sleep(forTimeInterval: Double.random(in: 0.1...0.3))
            print("Concurrent \(i)")  // 완료 순서 랜덤
        }
    }
}

// MARK: - 4. DispatchGroup — 여러 작업 완료를 한 번에 기다리기

func demonstrateDispatchGroup() {
    let group = DispatchGroup()
    var results: [String] = []

    // 작업 1
    group.enter()
    DispatchQueue.global().async {
        Thread.sleep(forTimeInterval: 0.5)
        results.append("Image downloaded")
        group.leave()
    }

    // 작업 2
    group.enter()
    DispatchQueue.global().async {
        Thread.sleep(forTimeInterval: 0.3)
        results.append("User data fetched")
        group.leave()
    }

    // 모두 완료 후 실행
    group.notify(queue: .main) {
        print("모든 작업 완료:", results)
    }
}

// MARK: - 5. DispatchBarrier — concurrent queue에서 쓰기 안전하게

class ThreadSafeArray<T> {
    private var array: [T] = []
    private let queue = DispatchQueue(label: "com.devjaeri.array", attributes: .concurrent)

    func append(_ value: T) {
        // barrier: 쓰기 시 다른 작업 모두 대기
        queue.async(flags: .barrier) {
            self.array.append(value)
        }
    }

    func read() -> [T] {
        // 읽기는 동시에 가능
        queue.sync { array }
    }
}
