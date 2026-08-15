//
//  RunManifestStore.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Darwin
import Foundation

// 완료 manifest의 저장 계약을 정의합니다.
package protocol RunManifestStoring: Sendable {
	// run별 디렉터리에 manifest를 원자적으로 저장하고 완료 파일 위치를 반환합니다.
	func store(_ manifest: RunManifest, in outputDirectoryURL: URL) throws -> URL
}

// manifest 저장이 사용하는 파일 관리 작업을 정의합니다.
package protocol RunManifestFileManaging: Sendable {
	// 필요한 디렉터리를 선택한 중간 경로 생성 정책으로 생성합니다.
	func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
	// 파일 존재 여부를 반환합니다.
	func fileExists(at url: URL) -> Bool
	// 경로가 symbolic link인지 반환합니다.
	func isSymbolicLink(at url: URL) throws -> Bool
	// 다른 저장 작업과 충돌하지 않도록 process lock을 획득합니다.
	func acquireLock(at url: URL) throws -> any RunManifestLocking
	// data를 파일에 기록합니다.
	func write(_ data: Data, to url: URL) throws
	// 파일을 rename합니다.
	func moveItem(at sourceURL: URL, to destinationURL: URL) throws
	// 파일을 제거합니다.
	func removeItem(at url: URL) throws
}

// manifest 저장 중 유지할 process lock의 해제 계약을 정의합니다.
package protocol RunManifestLocking: Sendable {
	// process lock을 해제합니다.
	func release()
}

// Foundation FileManager로 manifest 파일 작업을 수행합니다.
package struct FoundationRunManifestFileManager: RunManifestFileManaging {
	// 기본 파일 관리자로 구성합니다.
	package init() {}

	// 선택한 중간 경로 생성 정책으로 디렉터리를 생성합니다.
	package func createDirectory(
		at url: URL,
		withIntermediateDirectories: Bool
	) throws {
		try FileManager.default.createDirectory(
			at: url,
			withIntermediateDirectories: withIntermediateDirectories
		)
	}

	// 파일 존재 여부를 반환합니다.
	package func fileExists(at url: URL) -> Bool {
		FileManager.default.fileExists(atPath: url.path)
	}

	// 마지막 경로 구성요소를 따라가지 않고 symbolic link 여부를 확인합니다.
	package func isSymbolicLink(at url: URL) throws -> Bool {
		var fileStatus = stat()
		guard lstat(url.path, &fileStatus) == 0 else {
			guard errno == ENOENT else {
				throw RunManifestFileManagerError.operationFailed
			}

			return false
		}

		return fileStatus.st_mode & S_IFMT == S_IFLNK
	}

	// 다른 저장 작업과 충돌하지 않도록 process lock을 획득합니다.
	package func acquireLock(at url: URL) throws -> any RunManifestLocking {
		let descriptor = open(url.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)

		guard descriptor != -1 else {
			throw RunManifestFileManagerError.operationFailed
		}
		guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
			let errorCode = errno
			_ = close(descriptor)
			if errorCode == EWOULDBLOCK {
				throw RunManifestFileManagerError.lockUnavailable
			}
			throw RunManifestFileManagerError.operationFailed
		}

		return FoundationRunManifestLock(descriptor: descriptor)
	}

	// data를 새 파일에 기록합니다.
	package func write(_ data: Data, to url: URL) throws {
		try data.write(to: url, options: .withoutOverwriting)
	}

	// 임시 파일을 완료 파일 위치로 rename합니다.
	package func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
		try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
	}

	// 임시 파일만 제거합니다.
	package func removeItem(at url: URL) throws {
		try FileManager.default.removeItem(at: url)
	}
}

// Foundation file descriptor로 유지하는 manifest process lock을 표현합니다.
package struct FoundationRunManifestLock: RunManifestLocking {
	private let descriptor: Int32

	// 열린 file descriptor로 process lock을 구성합니다.
	package init(descriptor: Int32) {
		self.descriptor = descriptor
	}

	// file descriptor를 닫아 process lock을 해제합니다.
	package func release() {
		_ = close(descriptor)
	}
}

// 완료 manifest만 run별 디렉터리에 원자적으로 기록합니다.
package struct RunManifestStore: RunManifestStoring {
	private let fileManager: any RunManifestFileManaging
	private let codec: RunManifestCodec

	// 주입한 파일 관리자와 JSON codec으로 저장소를 구성합니다.
	package init(
		fileManager: any RunManifestFileManaging = FoundationRunManifestFileManager(),
		codec: RunManifestCodec = .init()
	) {
		self.fileManager = fileManager
		self.codec = codec
	}

	// run별 임시 파일을 기록한 뒤 완료 manifest로 rename합니다.
	package func store(_ manifest: RunManifest, in outputDirectoryURL: URL) throws -> URL {
		let runDirectoryURL = outputDirectoryURL.standardizedFileURL
			.appendingPathComponent(manifest.id.uuidString, isDirectory: true)
		let manifestURL = runDirectoryURL.appendingPathComponent("manifest.json", isDirectory: false)
		let lockURL = runDirectoryURL.appendingPathComponent(".manifest.lock", isDirectory: false)
		let temporaryURL = runDirectoryURL.appendingPathComponent(
			"manifest.json.\(UUID().uuidString).tmp",
			isDirectory: false
		)

		do {
			try fileManager.createDirectory(
				at: outputDirectoryURL.standardizedFileURL,
				withIntermediateDirectories: true
			)
			guard try !fileManager.isSymbolicLink(at: runDirectoryURL) else {
				throw RunManifestStoreError.storageFailed
			}
			try fileManager.createDirectory(
				at: runDirectoryURL,
				withIntermediateDirectories: true
			)
			guard try !fileManager.isSymbolicLink(at: runDirectoryURL) else {
				throw RunManifestStoreError.storageFailed
			}
		} catch {
			throw RunManifestStoreError.storageFailed
		}

		let lock: any RunManifestLocking
		do {
			lock = try fileManager.acquireLock(at: lockURL)
		} catch RunManifestFileManagerError.lockUnavailable {
			throw RunManifestStoreError.manifestExists
		} catch {
			throw RunManifestStoreError.storageFailed
		}
		defer { lock.release() }

		guard !fileManager.fileExists(at: manifestURL) else {
			throw RunManifestStoreError.manifestExists
		}

		do {
			try fileManager.write(codec.encode(manifest), to: temporaryURL)
			try fileManager.moveItem(at: temporaryURL, to: manifestURL)
		} catch {
			try? fileManager.removeItem(at: temporaryURL)
			throw RunManifestStoreError.storageFailed
		}

		return manifestURL
	}
}

// manifest 저장 과정에서 외부로 노출할 오류를 정의합니다.
package enum RunManifestStoreError: Error, Sendable, Equatable {
	case manifestExists
	case storageFailed
}

// Foundation 파일 관리 작업의 저장소용 오류를 정의합니다.
package enum RunManifestFileManagerError: Error, Sendable, Equatable {
	case lockUnavailable
	case operationFailed
}
