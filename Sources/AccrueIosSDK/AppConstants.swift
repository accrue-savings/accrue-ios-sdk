//
//  AppConstants.swift
//  accrue-ios-sdk
//
//  Created by Otavio Henrique Pires Costa on 03/08/24.
//

public struct AppConstants {
    static let apiBaseUrl:String = "https://accrue-embed-git-ios-implementation-accrue-money.vercel.app/webview"
    static let merchantId: String = "7ac10172-c0bd-4009-a85a-972d33efbd04"
    static let redirectionToken = "redirection-token"
}
public struct AccrueWebEvents {
    static let EventHandlerName:String = "AccrueWallet"
    static let AccrueWalletSignInPerfomerdMessageKey:String = "AccrueWallet::SignInPerformed"
}
