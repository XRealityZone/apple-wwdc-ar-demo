/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utilities for compact serialization of data structures for network transmission.
*/

import Foundation

enum BitStreamError: Error {
    case tooShort
    case encodingError
    case decodingError
}

struct FloatCompressor {
    var minValue: Float
    var maxValue: Float
    var bits: Int
    private var maxBitValue: Double

    init(minValue: Float, maxValue: Float, bits: Int) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.bits = bits
        self.maxBitValue = pow(2.0, Double(bits)) - 1 // for 8 bits, highest value is 255, not 256
    }

    func write(_ value: Float, to string: inout WritableBitStream) {
        let ratio = Double((value - minValue) / (maxValue - minValue))
        let clampedRatio = max(0.0, min(1.0, ratio))
        let bitPattern = UInt32(clampedRatio * maxBitValue)
        string.appendUInt32(bitPattern, numberOfBits: bits)
    }

    func write(_ value: SIMD3<Float>, to string: inout WritableBitStream) {
        write(value.x, to: &string)
        write(value.y, to: &string)
        write(value.z, to: &string)
    }

    func read(from string: inout ReadableBitStream) throws -> Float {
        let bitPattern = try string.readUInt32(numberOfBits: bits)

        let ratio = Float(Double(bitPattern) / maxBitValue)
        return  ratio * (maxValue - minValue) + minValue
    }

    func readFloat3(from string: inout ReadableBitStream) throws -> SIMD3<Float> {
        return SIMD3<Float>(
            x: try read(from: &string),
            y: try read(from: &string),
            z: try read(from: &string)
        )
    }
}

/// Gets the number of bits required to encode an enum case.
extension RawRepresentable where Self: CaseIterable, RawValue == UInt32 {
    static var bits: Int {
        let casesCount = UInt32(allCases.count)
        return UInt32.bitWidth - casesCount.leadingZeroBitCount
    }
}

struct WritableBitStream {
    var bytes = [UInt8]()
    var endBitIndex = 0

    var description: String {
        var result = "bitStream \(endBitIndex): "
        for index in 0..<bytes.count {
            result.append((String(bytes[index], radix: 2) + " "))
        }
        return result
    }

    // MARK: - Append

    mutating func appendBool(_ value: Bool) {
        appendBit(UInt8(value ? 1 : 0))
    }

    mutating func appendBits<T: SignedInteger>(_ value: T) where T: FixedWidthInteger {
        var tempValue = value
        let numberOfBits = value.bitWidth
        for _ in 0..<numberOfBits {
            appendBit(UInt8(tempValue & 1))
            tempValue >>= 1
        }
    }

    mutating func appendInt8(_ value: Int8) {
        appendBits(value)
    }

    mutating func appendInt16(_ value: Int16) {
        appendBits(value)
    }

    mutating func appendBits<T: UnsignedInteger>(_ value: T) where T: FixedWidthInteger {
        var tempValue = value
        let numberOfBits = value.bitWidth
        for _ in 0..<numberOfBits {
            appendBit(UInt8(tempValue & 1))
            tempValue >>= 1
        }
    }

    mutating func appendUInt8(_ value: UInt8) {
        appendBits(value)
    }

    mutating func appendUInt16(_ value: UInt16) {
        appendBits(value)
    }

    mutating func appendInt32(_ value: Int32) {
        appendInt32(value, numberOfBits: value.bitWidth)
    }

    mutating func appendInt32(_ value: Int32, numberOfBits: Int) {
        var tempValue = value
        for _ in 0..<numberOfBits {
            appendBit(UInt8(tempValue & 1))
            tempValue >>= 1
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        appendUInt32(value, numberOfBits: value.bitWidth)
    }

    mutating func appendUInt32(_ value: UInt32, numberOfBits: Int) {
        var tempValue = value
        for _ in 0..<numberOfBits {
            appendBit(UInt8(tempValue & 1))
            tempValue >>= 1
        }
    }

    mutating func appendInt64(_ value: Int64) {
        appendInt64(value, numberOfBits: value.bitWidth)
    }

    mutating func appendInt64(_ value: Int64, numberOfBits: Int) {
        var tempValue = value
        for _ in 0..<numberOfBits {
            appendBit(UInt8(tempValue & 1))
            tempValue >>= 1
        }
    }

    // Appends an integer-based enum using the minimal number of bits for its set of possible cases.
    mutating func appendEnum<T>(_ value: T) where T: CaseIterable & RawRepresentable, T.RawValue == UInt32 {
        appendUInt32(value.rawValue, numberOfBits: type(of: value).bits)
    }

    mutating func appendFloat(_ value: Float) {
        appendUInt32(value.bitPattern)
    }

    mutating func appendString(_ value: String) {
        guard let data = value.data(using: .utf8) else {
            fatalError(String(format: "appendString() failed to create utf8 Data for string '%s'", "\(value)"))
        }
        append(data)
    }

    mutating func append(_ value: Data) {
        align()
        let length = UInt32(value.count)
        appendUInt32(length)
        bytes.append(contentsOf: value)
        endBitIndex += Int(length * 8)
    }

    mutating private func appendBit(_ value: UInt8) {
        let bitShift = endBitIndex % 8
        let byteIndex = endBitIndex / 8
        if bitShift == 0 {
            bytes.append(UInt8(0))
        }

        bytes[byteIndex] |= UInt8(value << bitShift)
        endBitIndex += 1
    }

    mutating private func align() {
        // skip over any remaining bits in the current byte
        endBitIndex = bytes.count * 8
    }

    // MARK: - Finalize Data

    func finalize() -> Data {
        //
        // Insert total count of bytes in stream at beginning
        // of byte stream
        //
        let endBitIndex32 = UInt32(endBitIndex)
        let endBitIndexBytes = [UInt8(truncatingIfNeeded: endBitIndex32),
                                UInt8(truncatingIfNeeded: endBitIndex32 >> 8),
                                UInt8(truncatingIfNeeded: endBitIndex32 >> 16),
                                UInt8(truncatingIfNeeded: endBitIndex32 >> 24)]
        var result = Data(capacity: 4 + bytes.count)
        result.append(contentsOf: endBitIndexBytes)
        result.append(contentsOf: bytes)
        return result
    }
}

struct ReadableBitStream {
    var bytes = [UInt8]()
    var endBitIndex: Int
    var currentBit = 0
    var isAtEnd: Bool { return currentBit == endBitIndex }

    init(data: Data) {
        var bytes = [UInt8](data)

        if bytes.count < 4 {
            fatalError("failed to init bitstream")
        }

        var endBitIndex32 = UInt32(bytes[0])
        endBitIndex32 |= (UInt32(bytes[1]) << 8)
        endBitIndex32 |= (UInt32(bytes[2]) << 16)
        endBitIndex32 |= (UInt32(bytes[3]) << 24)
        endBitIndex = Int(endBitIndex32)

        bytes.removeSubrange(0...3)
        self.bytes = bytes
    }

    // MARK: - Read

    mutating func readBool() throws -> Bool {
        if currentBit >= endBitIndex {
            throw BitStreamError.tooShort
        }
        return (readBit() > 0) ? true : false
    }

    mutating func readFloat() throws -> Float {
        var result: Float = 0.0
        do {
            result = try Float(bitPattern: readUInt32())
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readBits<T: SignedInteger>() throws -> T where T: FixedWidthInteger {
        var bitPattern: T = 0
        let numberOfBits = bitPattern.bitWidth
        if currentBit + numberOfBits > endBitIndex {
            throw BitStreamError.tooShort
        }

        for index in 0..<numberOfBits {
            bitPattern |= (T(readBit()) << index)
        }

        return bitPattern
    }

    mutating func readInt8() throws -> Int8 {
        var result: Int8 = 0
        do {
            result = try readBits()
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readInt16() throws -> Int16 {
        var result: Int16 = 0
        do {
            result = try readBits()
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readBits<T: UnsignedInteger>() throws -> T where T: FixedWidthInteger {
        var bitPattern: T = 0
        let numberOfBits = bitPattern.bitWidth
        if currentBit + numberOfBits > endBitIndex {
            throw BitStreamError.tooShort
        }

        for index in 0..<numberOfBits {
            bitPattern |= (T(readBit()) << index)
        }

        return bitPattern
    }

    mutating func readUInt8() throws -> UInt8 {
        var result: UInt8 = 0
        do {
            result = try readBits()
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readUInt16() throws -> UInt16 {
        var result: UInt16 = 0
        do {
            result = try readBits()
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readInt32() throws -> Int32 {
        var result: Int32 = 0
        do {
            result = try readInt32(numberOfBits: Int32.bitWidth)
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readInt32(numberOfBits: Int) throws -> Int32 {
        if currentBit + numberOfBits > endBitIndex {
            throw BitStreamError.tooShort
        }

        var bitPattern: Int32 = 0
        for index in 0..<numberOfBits {
            bitPattern |= (Int32(readBit()) << index)
        }

        return bitPattern
    }

    mutating func readUInt32() throws -> UInt32 {
        var result: UInt32 = 0
        do {
            result = try readUInt32(numberOfBits: UInt32.bitWidth)
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readUInt32(numberOfBits: Int) throws -> UInt32 {
        if currentBit + numberOfBits > endBitIndex {
            throw BitStreamError.tooShort
        }

        var bitPattern: UInt32 = 0
        for index in 0..<numberOfBits {
            bitPattern |= (UInt32(readBit()) << index)
        }

        return bitPattern
    }

    mutating func readInt64() throws -> Int64 {
        var result: Int64 = 0
        do {
            result = try readInt64(numberOfBits: Int64.bitWidth)
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readInt64(numberOfBits: Int) throws -> Int64 {
        if currentBit + numberOfBits > endBitIndex {
            throw BitStreamError.tooShort
        }

        var bitPattern: Int64 = 0
        for index in 0..<numberOfBits {
            bitPattern |= (Int64(readBit()) << index)
        }

        return bitPattern
    }

    mutating func readString() throws -> String {
        var result: String = ""
        do {
            let data = try readData()
            guard let string = String(data: data, encoding: .utf8) else {
                throw BitStreamError.decodingError
            }
            result = string
        } catch let error {
            throw error
        }
        return result
    }

    mutating func readData() throws -> Data {
        align()
        let length = Int(try readUInt32())
        assert(currentBit % 8 == 0)
        guard currentBit + (length * 8) <= endBitIndex else {
            throw BitStreamError.tooShort
        }
        let currentByte = currentBit / 8
        let endByte = currentByte + length

        let result = Data(bytes[currentByte..<endByte])
        currentBit += length * 8
        return result
    }

    mutating func readEnum<T>() throws -> T where T: CaseIterable & RawRepresentable, T.RawValue == UInt32 {
        let rawValue = try readUInt32(numberOfBits: T.bits)
        guard let result = T(rawValue: rawValue) else {
            throw BitStreamError.encodingError
        }
        return result
    }

    mutating private func align() {
        let mod = currentBit % 8
        if mod != 0 {
            currentBit += 8 - mod
        }
    }

    mutating private func readBit() -> UInt8 {
        let bitShift = currentBit % 8
        let byteIndex = currentBit / 8
        currentBit += 1
        return (bytes[byteIndex] >> bitShift) & 1
    }
}

extension String: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        self = try bitStream.readString()
    }

    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendString(self)
    }
}
