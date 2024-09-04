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
 
