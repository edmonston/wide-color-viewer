//
//  PreviewView.swift
//  VideoCaptureTest
//
//  Created by Peter Edmonston on 11/26/17.
//  Copyright © 2017 com.peteredmonston. All rights reserved.
//

import UIKit
import AVKit

class PreviewView: UIView {
    var session: AVCaptureSession? {
        didSet {
            (layer as? AVCaptureVideoPreviewLayer)?.session = session
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
