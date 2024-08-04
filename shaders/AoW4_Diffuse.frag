#version 450

layout(location = 0) in vec2 fragTexCoord;

layout(set = 1, binding = 1) uniform sampler2D diffuseTexture;

layout(location = 0) out vec4 outColor;

void main()
{
    vec3 Color = texture(diffuseTexture, fragTexCoord).rgb;
    outColor = vec4(Color, 1.0);
    // outColor = texture(diffuseTexture, fragTexCoord).aaaa;
}
