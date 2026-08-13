//
//  StandardOutputDrainer.swift
//  QALenz
//
//  Created by opfic on 8/13/26.
//

import Darwin
import Foundation

// Darwin FIONREAD로 pipe의 현재 buffer만 회수합니다.
// FIONREAD: 파일 디스크립터에서 지금 즉시 읽을 수 있는 바이트 수를 조회하는 ioctl 요청
enum StandardOutputDrainer {
	private static let bytesAvailableRequest = UInt(0x4004667F)

	// 현재 읽을 수 있는 바이트 수를 고정한 뒤 해당 범위만 반환합니다.
	static func drainBufferedData(from handle: FileHandle) -> Data {
		var availableByteCount = Int32.zero
		guard
			ioctl(handle.fileDescriptor, Self.bytesAvailableRequest, &availableByteCount) == 0,
			0 < availableByteCount
		else { return Data() }

		let targetByteCount = Int(availableByteCount)
		var data = Data(count: targetByteCount)
		var offset = 0

		while offset < targetByteCount {
			let readByteCount = data.withUnsafeMutableBytes { buffer in
				guard let baseAddress = buffer.baseAddress else { return 0 }

				return Darwin.read(handle.fileDescriptor, baseAddress.advanced(by: offset), targetByteCount - offset)
			}
			if readByteCount == -1, errno == EINTR {
				continue
			}
			guard 0 < readByteCount else { break }

			offset += readByteCount
		}

		if offset < targetByteCount {
			data.removeSubrange(offset...)
		}

		return data
	}
}
