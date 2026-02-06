import AppKit
import Darwin

switch CliClient.detectMode() {
case .help:
    CliClient.printHelp()
    exit(0)
case .sendCommand(let command):
    CliClient.sendCommandAndProcessResponse(command)
case .unsupported(let command):
    print("Unsupported command in headless mode: \(command)")
    print("Supported commands: --list, --detailed-list, --help")
    exit(1)
case .invalid:
    CliClient.printHelp()
    exit(1)
case .daemon:
    break
}

[SIGTERM, SIGTRAP].forEach {
    signal($0) { s in
        emergencyExit("Exiting after receiving signal", s)
    }
}

NSSetUncaughtExceptionHandler { exception in
    emergencyExit("Exiting after receiving uncaught NSException", exception)
}

App.shared.run()

func printStackTrace() {
    let stackSymbols = Thread.callStackSymbols
    for symbol in stackSymbols {
        print(symbol)
    }
}

fileprivate func emergencyExit(_ logs: Any?...) {
    print(logs)
    printStackTrace()
    exit(1)
}
