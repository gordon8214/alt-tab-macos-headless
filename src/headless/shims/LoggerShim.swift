import Foundation

class Logger {
    private enum Level: Int {
        case verbose
        case debug
        case info
        case warning
        case error

        var label: String {
            switch self {
            case .verbose: return "VERB"
            case .debug: return "DEBG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERRO"
            }
        }
    }

    static let flag = "--logs="
    static let longDateTimeFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    static let shortDateTimeFormat = "HH:mm:ss"

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = longDateTimeFormat
        return formatter
    }()

    private static var minimumLevel = Level.error

    static func initialize() {
        minimumLevel = decideLevel()
    }

    private static func decideLevel() -> Level {
        if let level = (CommandLine.arguments.first { $0.starts(with: flag) })?.dropFirst(flag.count) {
            switch level {
            case "verbose": return .verbose
            case "debug": return .debug
            case "info": return .info
            case "warning": return .warning
            case "error": return .error
            default: break
            }
        }
        return .error
    }

    static func debug(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .debug, file: file, function: function, line: line, context: context, message)
    }

    static func info(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .info, file: file, function: function, line: line, context: context, message)
    }

    static func warning(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .warning, file: file, function: function, line: line, context: context, message)
    }

    static func error(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {
        custom(level: .error, file: file, function: function, line: line, context: context, message)
    }

    private static func custom(level: Level, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil, _ message: @escaping () -> Any?) {
        guard level.rawValue >= minimumLevel.rawValue else { return }
        let source = "\((file as NSString).lastPathComponent):\(line) \(function)"
        let contextPart = context.flatMap { " context=\($0)" } ?? ""
        let messagePart = String(describing: message() ?? "nil")
        let logLine = "\(formatter.string(from: Date())) \(level.label) [\(threadName())] \(source)\(contextPart) \(messagePart)\n"
        if level == .warning || level == .error {
            fputs(logLine, stderr)
        } else {
            fputs(logLine, stdout)
        }
    }

    private static func threadName() -> String {
        if Thread.isMainThread {
            return "main"
        }
        if let name = Thread.current.name, !name.isEmpty {
            return name
        }
        let queueLabel = __dispatch_queue_get_label(nil)
        return String(cString: queueLabel, encoding: .utf8) ?? Thread.current.description
    }
}
