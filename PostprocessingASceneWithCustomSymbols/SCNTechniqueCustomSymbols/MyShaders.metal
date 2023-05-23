/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Basic Shaders.
*/

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texcoord0 [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
};

struct Symbols {
    float3 color_weights;
    float time;
};

vertex VertexOut myVertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texcoord = float2((in.position.x + 1.0) * 0.5, (in.position.y + 1.0) * -0.5);
    return out;
};

constexpr sampler s = sampler(coord::normalized, address::repeat, filter::nearest);

fragment half4 myFragmentShader(VertexOut in [[stage_in]],
                                constant Symbols &symbols [[buffer(0)]],
                                texture2d<half, access::sample> color [[texture(0)]]) {
    
    half4 out = color.sample(s, in.texcoord);
    out.r = out.r*symbols.color_weights[0];
    out.g = out.g*symbols.color_weights[1]*symbols.time;
    out.b = out.b*symbols.color_weights[2]*symbols.time;
    
    return out;
};


