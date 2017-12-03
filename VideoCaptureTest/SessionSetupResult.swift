//
//  SessionSetupResult.swift
//  VideoCaptureTest
//
//  Created by Peter Edmonston on 12/3/17.
//  Copyright © 2017 com.peteredmonston. All rights reserved.
//

import Foundation

enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
    
    var errorMessage: String {
        switch self {
        case .success: return ""
        case .notAuthorized: return "Please allow camera access"
        case .configurationFailed: return "Camera setup failed"
        }
    }
}
