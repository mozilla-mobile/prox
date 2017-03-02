/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

enum LoggerLevel: Int {
    case debug
    case info
    case warn
    case error
}

class Logger {
    private let tag: String

    var minPrintedLevel: LoggerLevel

    /// Create a Logger instance that prints messages with the given tag.
    /// Messages are filtered out if they are less than the given level.
    init(tag: String, minPrintedLevel: LoggerLevel) {
        self.tag = tag
        self.minPrintedLevel = minPrintedLevel
    }

    /// Create a Logger instance that prints messages with the given tag.
    /// Assigns the level based on the current build channel.
    convenience init(tag: String) {
        let minPrintedLevel: LoggerLevel = AppConstants.isDebug ? .debug : .info

        self.init(tag: tag, minPrintedLevel: minPrintedLevel)
    }

    func debug(_ message: Any?) {
        log(message, level: .debug)
    }

    func info(_ message: Any?) {
        log(message, level: .info)
    }

    func warn(_ message: Any?) {
        log(message, level: .warn)
    }

    func error(_ message: Any?) {
        log(message, level: .error)
    }

    private func log(_ message: Any?, level: LoggerLevel) {
        guard level.rawValue >= self.minPrintedLevel.rawValue else { return }
        NSLog("\(tag) [\(level)] \(message ?? "nil")")
    }
}

/// The default Logger instance.
let log = Logger(tag: "lol")
