//
//  File.swift
//  
//
//  Created by Otavio Henrique Pires Costa on 05/09/24.
//

import Foundation

class DeviceHelper {
    static func getInternalOSVersion() -> String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        
        var osversion = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &osversion, &size, nil, 0)
        
        return String(cString: osversion)
    }
    
    static func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? "Unknown"
    }
    static func getPackageVersion() -> String {
        return PackageVersion.version
    }
    
    static func parseDictionaryToJSONString(_ dictionary: [String: String]?) -> String {
        guard let dictionary = dictionary else {
            return "null"
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            print("Error converting dictionary to JSON: \(error)")
        }
        
        return "null" // Return "null" in case of an error
    }
}
