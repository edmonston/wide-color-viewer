//
//  filters.metal
//  VideoCaptureTest
//
//  Created by Peter Edmonston on 11/30/17.
//  Copyright © 2017 com.peteredmonston. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include <CoreImage/CoreImage.h> // includes CIKernelMetalLib.h

extern "C" {
    static bool isWideGamut(float value) {
        return value > 1.0 || value < 0.0;
    }
    
    namespace coreimage {
        float4 wide_color_kernel(sampler src) {
            float4 color = src.sample(src.coord());
            if (isWideGamut(color[0]) || isWideGamut(color[1]) || isWideGamut(color[2])) {
                // If the color is wide gamut, fully display it.
                return color;
            } else {
                // Otherwise grayscale the non-wide gamut colors.
                float3 grayscale = float3(0.3, 0.59, 0.11);
                float luminance = dot(grayscale, color.rgb);
                return float4(float3(luminance), 1.);
            }
        }
    }
}
