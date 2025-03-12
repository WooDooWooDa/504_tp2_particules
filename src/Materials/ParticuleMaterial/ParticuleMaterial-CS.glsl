#version 460

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

uniform vec3 GravityDir;
uniform float DeltaTime;
uniform float Mass;

layout(std140, binding = 0) buffer Positions
{
    vec4 Positiont[];
};

layout(std140, binding = 1) buffer Positions
{
    vec4 Positiont1[];
};

layout(std140, binding = 2) buffer Velocities
{
    vec4 Velocityt[];
};

layout(std140, binding = 3) buffer Velocities
{
    vec4 Velocityt1[];
};

void main() {

    
}