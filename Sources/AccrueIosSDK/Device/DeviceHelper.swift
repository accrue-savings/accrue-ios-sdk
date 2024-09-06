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
}
