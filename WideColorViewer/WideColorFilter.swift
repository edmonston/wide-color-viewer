//
//  CIWideFilter.swift
//  WideColorViewer
//
//  Created by Peter Edmonston on 11/30/17.
//  Copyright © 2017 com.peteredmonston. All rights reserved.
//

import Foundation
import CoreImage

class WideColorFilter: CIFilter {
    class KernelCreationError: Error {}
    class KernelNotInitializedError: Error {}
    
    private static var kernel: CIKernel?
    fileprivate static let name = "WideColor"
    
    static func setup() throws {
        guard let url = Bundle.main.url(forResource: "default", withExtension: "metallib"),
            let data = try? Data(contentsOf: url),
            let wideColorKernel = try? CIKernel(functionName: "wide_color_kernel",
                                       fromMetalLibraryData: data,
                                       outputPixelFormat: kCIFormatRGBAh) else {
                                       throw KernelCreationError()
        }
         kernel = wideColorKernel
         CIFilter.registerName(name,
                               constructor: FilterVendor(),
                               classAttributes: [kCIAttributeFilterName: name])
    }
    
    override var description: String {
        return("Whatever")
    }
    
    @objc var inputImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let kernel = WideColorFilter.kernel, let image = inputImage else { return nil }
        return kernel.apply(extent: image.extent,
                            roiCallback: { (_, rect) in rect },
                            arguments: [CISampler(image: image)])
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

