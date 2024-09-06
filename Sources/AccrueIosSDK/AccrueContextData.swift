import SwiftUI

@available(macOS 10.15, *)
public class AccrueContextData: ObservableObject {
    @Published public var  userData: AccrueUserData
    @Published public var  settingsData: AccrueSettingsData
    
    public init(
        userData: AccrueUserData = AccrueUserData(),
        settingsData: AccrueSettingsData = AccrueSettingsData()
    ) {
        self.userData = userData
        self.settingsData = settingsData
    }
    public func updateUserData(referenceId: String?, email: String?, phoneNumber: String?) {
        userData = AccrueUserData(referenceId: referenceId, email: email, phoneNumber: phoneNumber)
    }
    public func updateSettingsData(shouldInheritAuthentication: Bool) {
        settingsData = AccrueSettingsData(shouldInheritAuthentication: shouldInheritAuthentication)
    }

}

public struct AccrueUserData {
    public let referenceId: String?
    public let email: String?
    public let phoneNumber: String?
    
    public init(
        referenceId: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil
    ) {
        self.referenceId = referenceId
        self.email = email
        self.phoneNumber = phoneNumber
    }
}

public struct AccrueSettingsData {
    public let shouldInheritAuthentication: Bool
    
    public init( shouldInheritAuthentication: Bool = true) {
        self.shouldInheritAuthentication = shouldInheritAuthentication
    }
}
 
public struct AccrueDeviceContextData {
    public let sdk: String = "iOS"
    public let sdkVersion: String?
    public let brand: String?
    public let deviceName: String?
    public let deviceType: String?
    public let deviceYearClass: Double?
    public let isDevice: Bool
    public let manufacturer: String?
    public let modelName: String?
    public let osBuildId: String?
    public let osInternalBuildId: String?
    public let osName: String?
    public let osVersion: String?
    // iOS only
    public let modelId: String?
    
    public init(sdkVersion: String?, brand: String?, deviceName: String?, deviceType: String?, deviceYearClass: Double?, isDevice: Bool, manufacturer: String?, modelName: String?, osBuildId: String?, osInternalBuildId: String?, osName: String?, osVersion: String?, modelId: String?) {
        self.sdkVersion = sdkVersion
        self.brand = brand
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.deviceYearClass = deviceYearClass
        self.isDevice = isDevice
        self.manufacturer = manufacturer
        self.modelName = modelName
        self.osBuildId = osBuildId
        self.osInternalBuildId = osInternalBuildId
        self.osName = osName
        self.osVersion = osVersion
        self.modelId = modelId
    }
}
