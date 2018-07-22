//
//  GoogleLoginViewController.swift
//  ClockMagic
//
//  Created by H Hugo Falkman on 2018-07-22.
//  Copyright © 2018 H Hugo Falkman. All rights reserved.
//

import UIKit
import GoogleSignIn

class GoogleLoginViewController: UIViewController, GIDSignInUIDelegate {

    @IBOutlet weak var startMessage: UITextView!
    
    @IBOutlet weak var signInButton: GIDSignInButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure Google Sign-in and the sign-in button. Setup Start message.
        GIDSignIn.sharedInstance().uiDelegate = self
        signInButton.style = GIDSignInButtonStyle.wide
        signInButton.colorScheme = GIDSignInButtonColorScheme.dark
        startMessage.text = NSLocalizedString("Logga in på ditt Google-konto", comment: "Initially displayed message")
    }
}
