//
//  SortedImportsRule.swift
//  SwiftLint
//
//  Created by Scott Berrevoets on 12/15/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct SortedImportsRule: ConfigurationProviderRule, OptInRule, CorrectableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "sorted_imports",
        name: "Sorted Imports",
        description: "Imports should be sorted.",
        nonTriggeringExamples: [
            "import AAA\nimport BBB\nimport CCC\nimport DDD"
        ],
        triggeringExamples: [
            "import AAA\nimport ↓ZZZ\nimport ↓BBB\nimport ↓CCC"
        ]
    )

    public func modulesAndRanges(file: File) -> [(module: String, range: NSRange)] {
        let importRanges = file.match(pattern: "import\\s+\\w+", with: [.keyword, .identifier])
        let contents = file.contents.bridge()

        let importAndSpaceLength = 7

        return importRanges.map { range in
            let moduleRange = NSRange(location: range.location + importAndSpaceLength,
                                      length: range.length - importAndSpaceLength)
            let moduleName = contents.substring(with: moduleRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (moduleName, moduleRange)
        }
    }

    public func validate(file: File) -> [StyleViolation] {

        let modulesAndRanges = self.modulesAndRanges(file: file)
        let sortedModulesAndRanges = modulesAndRanges.sorted {
            $0.module.localizedCompare($1.module) == .orderedAscending
        }

        return zip(modulesAndRanges, sortedModulesAndRanges)
            .filter { $0.module != $1.module }
            .map { (unsorted, _) in
                return StyleViolation(
                    ruleDescription: type(of: self).description,
                    severity: configuration.severity,
                    location: Location(
                        file: file,
                        characterOffset: unsorted.range.location
                    )
                )
        }
    }

    public func correct(file: File) -> [Correction] {

        let modulesAndRanges = self.modulesAndRanges(file: file)
        let sortedModulesAndRanges = modulesAndRanges.sorted {
            $0.module.localizedCompare($1.module) == .orderedAscending
        }

        var correctedContents = file.contents
        var corrections: [Correction] = []

        let violations = zip(modulesAndRanges, sortedModulesAndRanges).filter { $0.module != $1.module }

        for (unsorted, sorted) in violations.reversed() {
            correctedContents = correctedContents.bridge().replacingCharacters(in: unsorted.range, with: sorted.module)
            corrections.append(Correction( ruleDescription: type(of: self).description,
                                           location: Location(file: file, characterOffset: unsorted.range.location)))

        }

        if !corrections.isEmpty {
            file.write(correctedContents)
        }

        return corrections
    }
}
