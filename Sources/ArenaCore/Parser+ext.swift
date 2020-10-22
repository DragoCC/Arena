//
//  Parser+ext.swift
//  
//
//  Created by Sven A. Schmidt on 29/12/2019.
//

import Foundation
import Parser
import Path
import SemanticVersion


// https://mirrors.edge.kernel.org/pub/software/scm/git/docs/git-check-ref-format.html
let AllowedBranchCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-@/"))
let AllowedStartBranchCharacters = AllowedBranchCharacters.subtracting(CharacterSet(charactersIn: "/"))
let AllowedEndBranchCharacters = AllowedBranchCharacters.subtracting(CharacterSet(charactersIn: "/."))

let AllowedRevisionCharacters = CharacterSet.whitespacesAndNewlines.inverted


extension Parser where A == SemanticVersion {
    static var version: Parser<SemanticVersion> {
        zip(Parser<Int>.int,
            Parser<Void>.literal("."),
            Parser<Int>.int,
            Parser<Void>.literal("."),
            Parser<Int>.int)
            .map { major, _, minor, _, patch in
            SemanticVersion(major, minor, patch)
        }
    }
}


extension Parser where A == RefSpec {
    static var branch: Parser<RefSpec> {
        zip(Parser<Void>.literal("@branch:"), branchName).map { .branch(String($0.1)) }
    }

    static var exact: Parser<RefSpec> {
        zip(Parser<Void>.literal("@"), .version).map { .exact($0.1) }
    }

    static var from: Parser<RefSpec> {
        zip(Parser<Void>.literal("@from:"), .version).map { .from($0.1) }
    }

    static var noVersion: Parser<RefSpec> {
        Parser<Void>.end.map { .noVersion }
    }

    static var range: Parser<RefSpec> {
        oneOf([
            zip(Parser<Void>.literal("@"), .version, Parser<String>.string("..<"), .version),
            zip(Parser<Void>.literal("@"), .version, Parser<String>.string("..."), .version)
        ]).map { _, minVersion, rangeOp, maxVersion in
            rangeOp == "..<"
                ? .range(minVersion..<maxVersion)
                : .range(minVersion..<SemanticVersion(maxVersion.major, maxVersion.minor, maxVersion.patch + 1))
        }
    }

    static var revision: Parser<RefSpec> {
        zip(Parser<Void>.literal("@revision:"), Parser<Substring>.prefix(charactersIn: AllowedRevisionCharacters))
            .map { .revision(String($0.1)) }
    }

    static var refSpec: Parser<RefSpec> {
        let parsers: [Parser<RefSpec>] = [.branch, .exact, .from, .noVersion, .range, .revision]
        // ensure parsers are all exhaustive to reject matches from subset parsers, i.e.
        // @1.2.3..<2.0.0 -> .exact("1.2.3") + "..<2.0.0" rest instead of .range(@"1.2.3"..<"2.0.0")
        return oneOf(parsers.map { $0.exhaustive })
    }
}


extension Parser where A == Scheme {
    static var scheme: Parser<Scheme> {
        oneOf(Scheme.allCases.map {
                Parser<String>.string($0.rawValue)
                    .map { Scheme(rawValue: $0)! }
        })
    }
}


extension Parser where A == Foundation.URL {
    static var url: Parser<Foundation.URL> {
        zip(
            Parser<Scheme>.scheme,
            Parser<Substring>.prefix(upTo: "@").map(String.init)
        ).flatMap { (scheme, rest) in
            if let url = scheme.url(path: rest) {
                return always(url)
            }
            return .never
        }
    }
}


extension Parser where A == Dependency {
    static var dependency: Parser<Dependency> {
        zip(.url, .refSpec).map { Dependency(url: $0.0, refSpec: $0.1) }
    }
}


let branchName = zip(
    .char(in: AllowedStartBranchCharacters),
    .prefix(charactersIn: AllowedBranchCharacters)
).flatMap { res -> Parser<Substring> in
    let (head, tail) = res
    guard let last = tail.last, AllowedEndBranchCharacters.contains(character: last) else {
        return .never
    }
    return .always(String(head) + tail)
}
