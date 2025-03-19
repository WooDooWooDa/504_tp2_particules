#version 460

layout(local_size_x = 1000, local_size_y = 1, local_size_z = 1) in;

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

void ColliderWithPlane() {

}

void CollideWithBox() {
    //call collide with plane 6 times for each side
}

void main() {
    uint id = gl_LocalInvocationID.x;  // Get the unique index for this invocation

    if (id >= Positiont.length()) return;

    vec3 Fg = Mass * GravityDir * 9.81f;

    //Accélération
    vec3 acc = Fg / Mass;

    //Vitesse
    Velocityt1[id] = Velocityt[id] + vec4(acc * DeltaTime, 0);

    uint PlaneDist = 10;
    float SphereRadius = 0.3f;
    float impact = 0.8;
    float friction = 0.8f;
    vec4 Position = Positiont[id];

    vec4 n = vec4(0, 1, 0, 0); //normal du plancher
    vec4 a = vec4(0, -10, 0, 0); //point sur le plancher
    if (dot((Position - a), n) < SphereRadius) {
        // mettre a jour v prime
        vec4 Vper = dot(Velocityt1[id], n) * n;
        vec4 Vpar = Velocityt1[id] - dot(Velocityt1[id], n) * n;
        Velocityt1[id] = friction * Vpar - impact * Vper;

        // corriger position
        float d = SphereRadius - dot(Position - a, n);
        Positiont[id] = Positiont[id] + d * n;
    }

    //Position
    Positiont1[id] = Positiont[id] + (Velocityt1[id] * DeltaTime);
}