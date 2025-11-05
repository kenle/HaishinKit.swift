import Foundation
import os.log

final class DataBuffer {
    private(set) var capacity: Int
    private let baseCapacity: Int
    private let maxCapacity: Int
    private var data: Data
    private var head = 0
    private var tail = 0

    init(capacity: Int, maxCapacity: Int? = nil) {
        self.capacity = capacity
        self.baseCapacity = capacity
        self.maxCapacity = maxCapacity ?? capacity * 4 // limit to 4× by default
        self.data = Data(repeating: 0, count: capacity)
    }

    var bytes: UnsafePointer<UInt8>? {
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UnsafePointer<UInt8>? in
            bytes.baseAddress?.assumingMemoryBound(to: UInt8.self).advanced(by: head)
        }
    }

    var maxLength: Int {
        min(count, capacity - head)
    }

    private var count: Int {
        let value = tail - head
        return value < 0 ? value + capacity : value
    }

    @discardableResult
    func append(_ newData: Data) -> Bool {
        guard newData.count <= capacity else {
            // If new data is larger than current capacity, try to resize or reject.
            return resizeOrReject(newData)
        }

        guard newData.count + count < capacity else {
            return resizeOrReject(newData)
        }

        return data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) -> Bool in
            guard let pointer = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }

            let len = newData.count
            let firstChunk = min(len, capacity - tail)
            newData.copyBytes(to: pointer.advanced(by: tail), count: firstChunk)

            if firstChunk < len {
                // wrapped write
                let secondChunk = len - firstChunk
                newData[firstChunk..<len].copyBytes(to: pointer, count: secondChunk)
                tail = secondChunk
            } else {
                tail += len
                if tail == capacity { tail = 0 }
            }
            return true
        }
    }

    func skip(_ count: Int) {
        let length = min(count, capacity - head)
        if length < count {
            head = count - length
        } else {
            head += count
        }
        if head == capacity {
            head = 0
        }
    }

    func clear() {
        head = 0
        tail = 0
    }

    // --- Private Helpers ---

    private func resizeOrReject(_ newData: Data) -> Bool {
        // Avoid unbounded growth
        guard capacity < maxCapacity else {
            // Reached max capacity — reject or drop oldest data
            os_log("DataBuffer full — rejecting new data (%d bytes)", newData.count)
            return false
        }

        // Safe resize: double the capacity up to the max limit
        let newCapacity = min(capacity * 2, maxCapacity)
        os_log("Resizing buffer from %d to %d", capacity, newCapacity)

        var newDataStore = Data(repeating: 0, count: newCapacity)
        let currentCount = count

        // Copy existing bytes contiguously into newDataStore
        data.withUnsafeBytes { src in
            newDataStore.withUnsafeMutableBytes { dst in
                guard let srcPtr = src.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dstPtr = dst.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

                if head < tail {
                    memcpy(dstPtr, srcPtr.advanced(by: head), currentCount)
                } else if currentCount > 0 {
                    let firstLen = capacity - head
                    memcpy(dstPtr, srcPtr.advanced(by: head), firstLen)
                    memcpy(dstPtr.advanced(by: firstLen), srcPtr, tail)
                }
            }
        }

        data = newDataStore
        capacity = newCapacity
        head = 0
        tail = currentCount
        return append(newData)
    }
}

extension DataBuffer: CustomDebugStringConvertible {
    var debugDescription: String {
        "DataBuffer(capacity: \(capacity), head: \(head), tail: \(tail), count: \(count))"
    }
}