import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

@available(macOS 10.15, *)
public class AccrueContextData: ObservableObject {
    @Published public var userData: AccrueUserData
    @Published public var settingsData: AccrueSettingsData

    public init(
        userData: AccrueUserData = AccrueUserData(),
        settingsData: AccrueSettingsData = AccrueSettingsData()
    ) {
        self.userData = userData
        self.settingsData = settingsData
    }

    public func updateUserData(
        referenceId: String?, email: String?, phoneNumber: String?,
        additionalData: [String: String]?
    ) {
        userData = AccrueUserData(
            referenceId: referenceId, email: email, phoneNumber: phoneNumber,
            additionalData: additionalData)
    }

    public func updateSettingsData(shouldInheritAuthentication: Bool) {
        settingsData = AccrueSettingsData(shouldInheritAuthentication: shouldInheritAuthentication)
    }
}

public struct AccrueUserData {
    public let referenceId: String?
    public let email: String?
    public let phoneNumber: String?
    public let additionalData: [String: String]?

    public init(
        referenceId: String? = nil,
        email: String? = nil,
        phoneNumber: String? = nil,
        additionalData: [String: String]? = nil
    ) {
        self.referenceId = referenceId
        self.email = email
        self.phoneNumber = phoneNumber
        self.additionalData = additionalData
    }
}

public struct AccrueSettingsData {
    public let shouldInheritAuthentication: Bool

    public init(shouldInheritAuthentication: Bool = true) {
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

    public init(
        sdkVersion: String? = nil, brand: String? = nil, deviceName: String? = nil,
        deviceType: String? = nil, deviceYearClass: Double? = 0, isDevice: Bool? = true,
        manufacturer: String? = nil, modelName: String? = nil, osBuildId: String? = nil,
        osInternalBuildId: String? = nil, osName: String? = nil, osVersion: String? = nil,
        modelId: String? = nil
    ) {
        #if canImport(UIKit)
            self.sdkVersion = sdkVersion ?? DeviceHelper.getPackageVersion()
            self.brand = brand ?? "Apple"
            self.deviceName = deviceName ?? UIDevice.current.name
            self.deviceType = deviceType ?? UIDevice.current.model
            self.deviceYearClass = deviceYearClass
            self.isDevice = isDevice ?? true
            self.manufacturer = manufacturer ?? "Apple"
            self.modelName = modelName ?? UIDevice.current.model
            self.osBuildId = osBuildId ?? DeviceHelper.getInternalOSVersion()
            self.osInternalBuildId = osInternalBuildId ?? DeviceHelper.getInternalOSVersion()
            self.osName = osName ?? UIDevice.current.systemName
            self.osVersion = osVersion ?? UIDevice.current.systemVersion
            self.modelId = modelId ?? DeviceHelper.getModelIdentifier()
        #else
            self.sdkVersion = sdkVersion ?? DeviceHelper.getPackageVersion()
            self.brand = brand ?? "Apple"
            self.deviceName = deviceName
            self.deviceType = deviceType
            self.deviceYearClass = deviceYearClass
            self.isDevice = isDevice ?? true
            self.manufacturer = manufacturer ?? "Apple"
            self.modelName = modelName
            self.osBuildId = osBuildId ?? DeviceHelper.getInternalOSVersion()
            self.osInternalBuildId = osInternalBuildId ?? DeviceHelper.getInternalOSVersion()
            self.osName = osName
            self.osVersion = osVersion
            self.modelId = modelId ?? DeviceHelper.getModelIdentifier()
        #endif
    }
}
