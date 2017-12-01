//
//  CIWideFilter.swift
//  VideoCaptureTest
//
//  Created by Peter Edmonston on 11/30/17.
//  Copyright © 2017 com.peteredmonston. All rights reserved.
//

import Foundation
import CoreImage

class WideColorFilter: CIFilter {
    private static var _kernel: CIKernel!
    fileprivate static let name = "Wide"
    
    static func setup(with kernel: CIKernel) {
        _kernel = kernel
         CIFilter.registerName(name, constructor: FilterVendor(), classAttributes: [kCIAttributeFilterName: name])
    }
    
    override var description: String {
        return("Whatever")
    }
    
    @objc var inputImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let image = inputImage else { return nil }
        let sampler = CISampler(image: image)
        return WideColorFilter._kernel.apply(extent: image.extent, roiCallback: { (_, rect) in rect }, arguments: [sampler])
    }
}

class FilterVendor: NSObject, CIFilterConstructor {
    func filter(withName name: String) -> CIFilter? {
        switch name {
        case WideColorFilter.name: return WideColorFilter()
        default: return nil
        }
    }
}

