#version 460

layout(local_size_x = 100, local_size_y = 1, local_size_z = 1) in;

uniform vec3 GravityDir;
uniform float DeltaTime;
uniform float Mass;

layout(std140, binding = 0) buffer PositionsBuffer
{
    vec4 Positiont[];
};

layout(std140, binding = 1) buffer Positions1Buffer
{
    vec4 Positiont1[];
};

layout(std140, binding = 2) buffer VelocitiesBuffer
{
    vec4 Velocityt[];
};

layout(std140, binding = 3) buffer Velocities1Buffer
{
    vec4 Velocityt1[];
};

void main() {
    uint id = gl_LocalInvocationID.x;  // Get the unique index for this invocation

    if (id >= Positiont.length()) return;

    //Accélération
    vec3 acc = Mass * GravityDir;

    //Vitesse
    Velocityt1[id] = Velocityt[id] + vec4(acc * DeltaTime, 0);

    //Position
    Positiont1[id] = Positiont[id] + (Velocityt1[id] * DeltaTime);
}