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
    public func updateUserData(referenceId: String, email: String, phoneNumber: String) {
        userData = AccrueUserData(referenceId: referenceId, email: email, phoneNumber: phoneNumber)
    }
    public func updateSettingsData(disableLogout: Bool, loginRequiresReferenceId: Bool, skipPhoneInputScreen: Bool) {
        settingsData = AccrueSettingsData(disableLogout: disableLogout, loginRequiresReferenceId: loginRequiresReferenceId, skipPhoneInputScreen: skipPhoneInputScreen)
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
    public let disableLogout: Bool
    public let loginRequiresReferenceId: Bool
    public let skipPhoneInputScreen: Bool
    
    public init(
        disableLogout: Bool = false,
        loginRequiresReferenceId: Bool = false,
        skipPhoneInputScreen: Bool = false
    ) {
        self.disableLogout = disableLogout
        self.loginRequiresReferenceId = loginRequiresReferenceId
        self.skipPhoneInputScreen = skipPhoneInputScreen
    }
}
 
