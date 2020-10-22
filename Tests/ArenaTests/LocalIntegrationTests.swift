//
//  LocalIntegrationTests.swift
//  ArenaTests
//
//  Created by Sven A. Schmidt on 31/03/2020.
//

@testable import ArenaCore
import SnapshotTesting
import XCTest


class LocalIntegrationTests: XCTestCase {
    override func setUpWithError() throws {
        Current = .live
    }

    func test_output() throws {
        let arena = try Arena.parse([
            "https://github.com/finestructure/ArenaTest@0.0.3",
            "--name=ArenaIntegrationTest",
            "--force",
            "--skip-open"])

        let exp = self.expectation(description: "exp")

        var output = ""
        let progress: ProgressUpdate = { stage, msg in
            output += msg + "\n"
            if stage == .completed {
                exp.fulfill()
            }
        }

        try arena.run(progress: progress)

        wait(for: [exp], timeout: 10)

        assertSnapshot(matching: output, as: .lines, record: false)
    }

    // FIXME: fails on CI but shouldn't
    // https://github.com/finestructure/Arena/issues/43
    func test_Gen() throws {
        let arena = try Arena.parse([
            "https://github.com/pointfreeco/swift-gen@0.2.0",
            "--name=ArenaIntegrationTest",
            "--force",
            "--skip-open"])

        let exp = self.expectation(description: "exp")

        let progress: ProgressUpdate = { stage, _ in
            print("progress: \(stage)")
            if stage == .completed {
                exp.fulfill()
            }
        }

        try arena.run(progress: progress)

        wait(for: [exp], timeout: 10)
    }

    // Can't run on CI due to lacking ssh credentials
    func test_git_protocol() throws {
        let arena = try Arena.parse([
            "git@github.com:finestructure/ArenaTest@0.0.3",
            "--name=ArenaIntegrationTest",
            "--force",
            "--skip-open"])

        let exp = self.expectation(description: "exp")

        let progress: ProgressUpdate = { stage, _ in
            print("progress: \(stage)")
            if stage == .completed {
                exp.fulfill()
            }
        }

        try arena.run(progress: progress)

        wait(for: [exp], timeout: 10)
    }

}
