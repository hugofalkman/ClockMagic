//
//  GoogleLoginViewController.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-07-22.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit
import GoogleAPIClientForREST
import GoogleSignIn

extension Notification.Name {
    static let GoogleSignedIn = Notification.Name("GoogleSignedIn")
}

class GoogleLoginViewController: UIViewController, GIDSignInDelegate, GIDSignInUIDelegate {
    
    // MARK: - "Public" API
    
    let service = GTLRCalendarService()
    let service2 = GTLRPeopleServiceService()
    let service3 = GTLRDriveService()
    
    func signIn() {
        
        // Automatic Google Sign-in if access token saved in Keychain
        if TimingConstants.saveAuthorization && GIDSignIn.sharedInstance().hasAuthInKeychain() {
            GIDSignIn.sharedInstance().signInSilently()
        } else {
            GIDSignIn.sharedInstance().signOut()
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance().signOut()
    }
    
    // MARK: Private properties
    
    @IBOutlet private weak var startMessage: UITextView!
    @IBOutlet private weak var signInButton: GIDSignInButton!
    
    // If scopes change, delete access token in Keychain by uninstalling the app
    // or turning off the Save Authorization switch in Settings
    private let scopes = [
        kGTLRAuthScopeCalendarReadonly,
        kGTLRAuthScopePeopleServiceContactsReadonly,
        kGTLRAuthScopeDriveReadonly
    ]
    private lazy var services: [GTLRService] = { return [service,service2,service3] }()
    
    // MARK: - ViewController Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure User interface.
        signInButton.style = GIDSignInButtonStyle.wide
        signInButton.colorScheme = GIDSignInButtonColorScheme.dark
        startMessage.text = NSLocalizedString("Logga in på ditt Google-konto", comment: "Initially displayed message")
        
        // Configure Google Sign-in.
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = scopes
        GIDSignIn.sharedInstance().language = Locale.current.languageCode
        
        // Configure GTLR services
        services.forEach { service in
            service.isRetryEnabled = true
            service.maxRetryInterval = TimingConstants.googleTimeout
            service.callbackQueue = DispatchQueue.global()
        }
    }
    
    // MARK: - GID SignIn Delegate
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
              withError error: Error!) {
        var userInfo = [String: Any]()
        if let error = error {
            userInfo["error"] = error
            services.forEach { service in service.authorizer = nil }
        } else {
            let authorizer = user.authentication.fetcherAuthorizer()
            services.forEach { service in service.authorizer = authorizer }
            userInfo["name"] = user.profile.givenName
        }
        NotificationCenter.default.post(name: .GoogleSignedIn,
                                        object: self, userInfo: userInfo)
    }
}
