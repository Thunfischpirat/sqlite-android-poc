import Foundation
#if canImport(Cordova)
import Cordova
#endif

@objc(SqlitePoc)
class SqlitePoc: CDVPlugin {
    @objc func run(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            do {
                let directory = try FileManager.default.url(
                    for: .applicationSupportDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: true)
                let path = directory.appendingPathComponent("demo.sqlite").path
                guard let json = path.withCString({ sqlitePocRun($0) }) else {
                    throw NSError(domain: "SqlitePoc", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Could not allocate result"])
                }
                defer { sqlitePocFree(json) }
                let data = Data(String(cString: json).utf8)
                guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NSError(domain: "SqlitePoc", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid native result"])
                }
                let response: CDVPluginResult
                if let error = result["error"] as? String {
                    response = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error)
                } else {
                    response = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result)
                }
                self.commandDelegate.send(response, callbackId: command.callbackId)
            } catch {
                let response = CDVPluginResult(status: CDVCommandStatus_ERROR,
                                               messageAs: error.localizedDescription)
                self.commandDelegate.send(response, callbackId: command.callbackId)
            }
        }
    }
}
