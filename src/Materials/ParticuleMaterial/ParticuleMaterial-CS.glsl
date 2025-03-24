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

const uint PlaneDist = 10;
const float SphereRadius = 0.3f;
const float impact = 0.8;
const float friction = 0.8f;

void ColliderWithPlane(vec4 n, vec4 a, inout vec4 V, inout vec4 P) {
    if (dot((P - a), n) < SphereRadius) {
        // mettre a jour v prime
        vec4 Vper = dot(V, n) * n;
        vec4 Vpar = V - dot(V, n) * n;
        V = friction * Vpar - impact * Vper;

        // corriger position
        float d = SphereRadius - dot(P - a, n);
        P = P + d * n;
    }
}

void CollideWithBox(inout vec4 V, inout vec4 P) {
    //Colldie avec tout les cot�s
    ColliderWithPlane(vec4(0, 1, 0, 0), vec4(0, -10, 0, 0), V, P);  //Bottom
    ColliderWithPlane(vec4(0, -1, 0, 0), vec4(0, 10, 0, 0), V, P);  //Top
    
    ColliderWithPlane(vec4(1, 0, 0, 0), vec4(-10, 0, 0, 0), V, P);  //Left
    ColliderWithPlane(vec4(-1, 0, 0, 0), vec4(10, 0, 0, 0), V, P);  //Right
    
    ColliderWithPlane(vec4(0, 0, 1, 0), vec4(0, 0, -10, 0), V, P);  //Back
    ColliderWithPlane(vec4(0, 0, -1, 0), vec4(0, 0, 10, 0), V, P);  //Front
}

void main() {
    uint id = gl_LocalInvocationID.x;  // Get the unique index for this invocation

    if (id >= Positiont.length()) return;

    vec3 Fg = Mass * GravityDir * 9.81f;

    //Acc�l�ration
    vec3 acc = Fg / Mass;

    //Vitesse
    Velocityt1[id] = Velocityt[id] + vec4(acc * DeltaTime, 0);

    vec4 Position = Positiont[id];
    vec4 Velocity = Velocityt1[id];

    CollideWithBox(Velocity, Position);

    //Update velocity after collisions
    Velocityt1[id] = Velocity;

    //Position
    Positiont1[id] = Position + (Velocity * DeltaTime);
}