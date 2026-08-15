//
//  RunManifestStoreTests.swift
//  QALenz
//
//  Created by opfic on 8/15/26.
//

import Foundation
import Testing
@testable import QALenzCore

// RunManifestStore의 원자적 파일 기록을 검증합니다.
@Suite
struct RunManifestStoreTests {
	// task 전용 임시 디렉터리에 완료 manifest만 기록하는지 검증합니다.
	@Test
	func task_전용_임시_디렉터리에_완료_manifest만_기록한다() throws {
		let outputDirectoryURL = try makeOutputDirectoryURL()
		defer { try? FileManager.default.removeItem(at: outputDirectoryURL) }
		let manifest = manifest()

		let manifestURL = try RunManifestStore().store(manifest, in: outputDirectoryURL)
		let data = try Data(contentsOf: manifestURL)

		#expect(manifestURL.lastPathComponent == "manifest.json")
		#expect(manifestURL.deletingLastPathComponent().lastPathComponent == manifest.id.uuidString)
		#expect(try RunManifestCodec().decode(data) == manifest)
	}

	// 임시 파일 기록이 실패하면 완료 manifest를 rename하지 않는지 검증합니다.
	@Test
	func 임시_파일_기록이_실패하면_완료_manifest를_노출하지_않는다() {
		let fileManager = FailingRunManifestFileManager()
		let store = RunManifestStore(fileManager: fileManager)

		#expect(throws: RunManifestStoreError.self) {
			try store.store(manifest(), in: URL(fileURLWithPath: "/tmp/QALenz/Runs", isDirectory: true))
		}
		#expect(fileManager.movedURLs.isEmpty)
		#expect(fileManager.removedURLs.count == 1)
	}

	// 같은 run ID의 완료 manifest를 덮어쓰지 않는지 검증합니다.
	@Test
	func 같은_run_ID의_완료_manifest_덮어쓰기를_거부한다() throws {
		let outputDirectoryURL = try makeOutputDirectoryURL()
		defer { try? FileManager.default.removeItem(at: outputDirectoryURL) }
		let store = RunManifestStore()
		let manifest = manifest()

		_ = try store.store(manifest, in: outputDirectoryURL)

		#expect(throws: RunManifestStoreError.self) {
			try store.store(manifest, in: outputDirectoryURL)
		}
	}

	// 증거가 있는 기존 run 디렉터리에도 완료 manifest를 저장하는지 검증합니다.
	@Test
	func 증거가_있는_기존_run_디렉터리에_완료_manifest를_저장한다() throws {
		let outputDirectoryURL = try makeOutputDirectoryURL()
		defer { try? FileManager.default.removeItem(at: outputDirectoryURL) }
		let manifest = manifest()
		let evidenceDirectoryURL = outputDirectoryURL
			.appendingPathComponent(manifest.id.uuidString, isDirectory: true)
			.appendingPathComponent("evidence", isDirectory: true)
		try FileManager.default.createDirectory(at: evidenceDirectoryURL, withIntermediateDirectories: true)

		let manifestURL = try RunManifestStore().store(manifest, in: outputDirectoryURL)

		#expect(FileManager.default.fileExists(atPath: evidenceDirectoryURL.path))
		#expect(try RunManifestCodec().decode(Data(contentsOf: manifestURL)) == manifest)
	}

	// 동시에 같은 run ID를 저장해도 하나의 완료 manifest만 남는지 검증합니다.
	@Test
	func 동시에_같은_run_ID를_저장하면_하나의_manifest만_남는다() async throws {
		let outputDirectoryURL = try makeOutputDirectoryURL()
		defer { try? FileManager.default.removeItem(at: outputDirectoryURL) }
		let store = RunManifestStore()
		let manifest = manifest()
		let successes = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
			for _ in 0 ..< 2 {
				group.addTask {
					(try? store.store(manifest, in: outputDirectoryURL)) != nil
				}
			}

			return await group.reduce(into: []) { $0.append($1) }
		}
		let manifestURL = outputDirectoryURL
			.appendingPathComponent(manifest.id.uuidString, isDirectory: true)
			.appendingPathComponent("manifest.json", isDirectory: false)

		#expect(successes.filter { $0 }.count == 1)
		#expect(try RunManifestCodec().decode(Data(contentsOf: manifestURL)) == manifest)
	}

	// 기록 실패 뒤 같은 run ID로 다시 저장할 수 있는지 검증합니다.
	@Test
	func 기록_실패_뒤_같은_run_ID를_다시_저장할_수_있다() throws {
		let outputDirectoryURL = try makeOutputDirectoryURL()
		defer { try? FileManager.default.removeItem(at: outputDirectoryURL) }
		let manifest = manifest()
		let store = RunManifestStore(fileManager: OneTimeFailingRunManifestFileManager())

		#expect(throws: RunManifestStoreError.self) {
			try store.store(manifest, in: outputDirectoryURL)
		}
		let manifestURL = try store.store(manifest, in: outputDirectoryURL)

		#expect(try RunManifestCodec().decode(Data(contentsOf: manifestURL)) == manifest)
	}

	// 중단 뒤 남은 lock 파일이 있어도 같은 run ID를 저장할 수 있는지 검증합니다.
	@Test
	func 중단_뒤_남은_lock_파일이_있어도_같은_run_ID를_저장할_수_있다() throws {
		let outputDirectoryURL = try makeOutputDirectoryURL()
		defer { try? FileManager.default.removeItem(at: outputDirectoryURL) }
		let manifest = manifest()
		let runDirectoryURL = outputDirectoryURL
			.appendingPathComponent(manifest.id.uuidString, isDirectory: true)
		let lockURL = runDirectoryURL.appendingPathComponent(".manifest.lock", isDirectory: false)
		try FileManager.default.createDirectory(at: runDirectoryURL, withIntermediateDirectories: true)
		_ = FileManager.default.createFile(atPath: lockURL.path, contents: Data())

		let manifestURL = try RunManifestStore().store(manifest, in: outputDirectoryURL)

		#expect(try RunManifestCodec().decode(Data(contentsOf: manifestURL)) == manifest)
	}

	// output 디렉터리 생성 오류를 저장 오류로 분류하는지 검증합니다.
	@Test
	func output_디렉터리_생성_오류를_저장_오류로_분류한다() {
		let store = RunManifestStore(fileManager: DirectoryFailingRunManifestFileManager())

		do {
			_ = try store.store(manifest(), in: URL(fileURLWithPath: "/tmp/QALenz/Runs", isDirectory: true))
			#expect(Bool(false))
		} catch let error as RunManifestStoreError {
			#expect(error == .storageFailed)
		} catch {
			#expect(Bool(false))
		}
	}

	// task 전용 output 디렉터리를 반환합니다.
	private func makeOutputDirectoryURL() throws -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

		return url
	}

	// 저장할 최소 manifest를 반환합니다.
	private func manifest() -> RunManifest {
		.init(
			id: UUID(uuidString: "5D1A1E6B-5B08-4C4A-9E87-0B6D6B061601")!,
			createdAt: Date(timeIntervalSince1970: 0),
			scenario: .init(id: "todo-completion", profile: "default"),
			result: .passed,
			targets: []
		)
	}
}

// 기록 단계에서 오류를 발생시키는 파일 관리 시험 대역입니다.
private final class FailingRunManifestFileManager: RunManifestFileManaging, @unchecked Sendable {
	private(set) var movedURLs = [(source: URL, destination: URL)]()
	private(set) var removedURLs = [URL]()

	// 디렉터리 생성 요청을 허용합니다.
	func createDirectory(at _: URL, withIntermediateDirectories _: Bool) throws {}

	// 완료 manifest가 없다고 반환합니다.
	func fileExists(at _: URL) -> Bool {
		false
	}

	// 임시 manifest 기록을 보호할 process lock 요청을 허용합니다.
	func acquireLock(at _: URL) throws -> any RunManifestLocking {
		TestRunManifestLock()
	}

	// 임시 파일 기록에서 오류를 발생시킵니다.
	func write(_: Data, to _: URL) throws {
		throw TestFileManagerError.writeFailed
	}

	// rename 요청을 기록합니다.
	func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
		movedURLs.append((sourceURL, destinationURL))
	}

	// 임시 파일 삭제 요청을 기록합니다.
	func removeItem(at url: URL) throws {
		removedURLs.append(url)
	}
}

// 파일 관리 시험 대역이 발생시키는 오류를 정의합니다.
private enum TestFileManagerError: Error {
	case writeFailed
}

// 한 번의 임시 파일 기록만 실패시키는 파일 관리 시험 대역입니다.
private final class OneTimeFailingRunManifestFileManager: RunManifestFileManaging, @unchecked Sendable {
	private let fileManager = FoundationRunManifestFileManager()
	private var shouldFail = true

	// Foundation 파일 관리자로 디렉터리를 생성합니다.
	func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
		try fileManager.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
	}

	// Foundation 파일 관리자로 파일 존재 여부를 반환합니다.
	func fileExists(at url: URL) -> Bool {
		fileManager.fileExists(at: url)
	}

	// Foundation 파일 관리자로 process lock을 획득합니다.
	func acquireLock(at url: URL) throws -> any RunManifestLocking {
		try fileManager.acquireLock(at: url)
	}

	// 첫 기록만 실패시키고 이후에는 Foundation 파일 관리자로 기록합니다.
	func write(_ data: Data, to url: URL) throws {
		if shouldFail {
			shouldFail = false
			throw TestFileManagerError.writeFailed
		}
		try fileManager.write(data, to: url)
	}

	// Foundation 파일 관리자로 rename합니다.
	func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
		try fileManager.moveItem(at: sourceURL, to: destinationURL)
	}

	// Foundation 파일 관리자로 임시 파일을 제거합니다.
	func removeItem(at url: URL) throws {
		try fileManager.removeItem(at: url)
	}
}

// 디렉터리 생성 오류를 발생시키는 파일 관리 시험 대역입니다.
private struct DirectoryFailingRunManifestFileManager: RunManifestFileManaging {
	// 디렉터리 생성에서 오류를 발생시킵니다.
	func createDirectory(at _: URL, withIntermediateDirectories _: Bool) throws {
		throw TestFileManagerError.writeFailed
	}

	// 완료 manifest가 없다고 반환합니다.
	func fileExists(at _: URL) -> Bool {
		false
	}

	// process lock 요청을 허용합니다.
	func acquireLock(at _: URL) throws -> any RunManifestLocking {
		TestRunManifestLock()
	}

	// 기록 요청을 허용합니다.
	func write(_: Data, to _: URL) throws {}

	// rename 요청을 허용합니다.
	func moveItem(at _: URL, to _: URL) throws {}

	// 제거 요청을 허용합니다.
	func removeItem(at _: URL) throws {}
}

// 파일 관리 시험 대역이 반환하는 빈 process lock을 정의합니다.
private struct TestRunManifestLock: RunManifestLocking {
	// process lock 해제 요청을 허용합니다.
	func release() {}
}
