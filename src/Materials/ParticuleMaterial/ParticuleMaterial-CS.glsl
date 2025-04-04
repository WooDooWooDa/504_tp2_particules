#version 460

layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

uniform int NumParticules;
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

const int MaxParticulesInCell = 17;
ivec3 gridSize = ivec3(20, 20, 20);
shared uint mutex = 0;

struct ParticuleNode {
    int id;
    int next;
};

layout(std430, binding = 4) buffer ParticulesBuffer {
    ParticuleNode ParticulesNodeBuffer[];
};

layout(std430, binding = 5) buffer GridBuffer {
    int gridHead[];
};

int getGridIndex(vec4 pos) {
    ivec3 int_pos = ivec3(pos.xyz + vec3(10.0));  // [-10, 10] -> [0, 20]
    return int_pos.x + gridSize.x * (int_pos.y + gridSize.y * int_pos.z);
}

void updateParticuleCell(vec4 pos, uint id) {
    int cellIndex = getGridIndex(pos);

    int lastHead = atomicExchange(gridHead[cellIndex], int(id));
    atomicExchange(ParticulesNodeBuffer[gridHead[cellIndex]].next, lastHead);
}

void getObjectsInCell(int cellIndex, out int objectIds[MaxParticulesInCell]) {
    int headIndex = gridHead[cellIndex];
    int objIndex = headIndex;

    int i = 0;
    while (objIndex != -1 && i < MaxParticulesInCell) {
        ParticuleNode part = ParticulesNodeBuffer[objIndex];

        objectIds[i] = part.id;
        i++;
        
        objIndex = part.next;
    }

    if (objIndex == -1 && i < MaxParticulesInCell) {
        objectIds[i+1] = -1;
    }
}

void getNeighboringCells(int cellIndex, out int neighbors[7]) {
    int gridX = cellIndex % gridSize.x;
    int gridY = (cellIndex / gridSize.x) % gridSize.y;
    int gridZ = cellIndex / (gridSize.x * gridSize.y);

    neighbors[0] = cellIndex; // Current cell

    int count = 1;

    if (gridX > 0) neighbors[count++] = cellIndex - 1;                                      // Left
    if (gridX < gridSize.x - 1) neighbors[count++] = cellIndex + 1;                         // Right
    if (gridY > 0) neighbors[count++] = cellIndex - gridSize.x;                             // Bottom
    if (gridY < gridSize.y - 1) neighbors[count++] = cellIndex + gridSize.x;                // Top
    if (gridZ > 0) neighbors[count++] = cellIndex - (gridSize.x * gridSize.y);              // Back
    if (gridZ < gridSize.z - 1) neighbors[count++] = cellIndex + (gridSize.x * gridSize.y); // Front
}

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
    //Collide avec tout les cotés
    ColliderWithPlane(vec4(0, 1, 0, 0), vec4(0, -10, 0, 0), V, P);  //Bottom
    ColliderWithPlane(vec4(0, -1, 0, 0), vec4(0, 10, 0, 0), V, P);  //Top
    
    ColliderWithPlane(vec4(1, 0, 0, 0), vec4(-10, 0, 0, 0), V, P);  //Left
    ColliderWithPlane(vec4(-1, 0, 0, 0), vec4(10, 0, 0, 0), V, P);  //Right
    
    ColliderWithPlane(vec4(0, 0, 1, 0), vec4(0, 0, -10, 0), V, P);  //Back
    ColliderWithPlane(vec4(0, 0, -1, 0), vec4(0, 0, 10, 0), V, P);  //Front
}

void CollideWithLocalSpheres(uint id, inout vec4 V, inout vec4 P) {

    int objectIds[MaxParticulesInCell];
    int cellIndex = getGridIndex(P);
    int neighbors[7] = { -1, -1, -1, -1, -1, -1, -1 };
    getNeighboringCells(cellIndex, neighbors);

    for (uint i = 0; i < 7; ++i) {
        if (neighbors[i] == -1) continue;

        getObjectsInCell(neighbors[i], objectIds);
    
        for(uint i = 0; i < MaxParticulesInCell; ++i) {
            uint partId = objectIds[i];
            if (partId == -1) break;    //no more in cell
            if (partId == id) continue; //Dont check for self

            vec4 dir = Positiont[partId] - P;
            vec4 n = normalize(dir);
            float dist = length(dir);

            //collision?
            if (dist < SphereRadius) {
                //corriger pos
                float d = (SphereRadius - dist) * 0.5;
                P -= d * n;
                Positiont[partId] += d * n;

                vec4 VelocityPrime = Velocityt1[partId];

                vec4 VelocityPrimePerpendicular = dot(VelocityPrime, n) * n;
                vec4 VelocityPrimeParallel = VelocityPrime - VelocityPrimePerpendicular;

                vec4 VelocityPerpendicular = dot(V, n) * n;
                vec4 VelocityParallel = V - VelocityPerpendicular;

                //échanger vitesse per.
                V = VelocityParallel + VelocityPrimePerpendicular;
                Velocityt1[partId] = VelocityPrimeParallel + VelocityPerpendicular;
            }
        }
    }
}

void main() {

    
    uint id = (gl_WorkGroupID.x * gl_WorkGroupSize.x) + gl_LocalInvocationID.x;  // Get the unique index for this invocation

    if (id >= Positiont.length()) return;

    vec3 Fg = Mass * GravityDir * 9.81f;

    //Accélération
    vec3 acc = Fg / Mass;

    //Vitesse
    Velocityt1[id] = Velocityt[id] + vec4(acc * DeltaTime, 0);

    vec4 Position = Positiont[id];
    vec4 Velocity = Velocityt1[id];

    int cellIndex = getGridIndex(Position);

    CollideWithBox(Velocity, Position);
    CollideWithLocalSpheres(id, Velocity, Position);
    
    //Update velocity after collisions
    Velocityt1[id] = Velocity;

    //Position
    Positiont1[id] = Position + (Velocity * DeltaTime);
    
    //update grid cell
    updateParticuleCell(Positiont1[id], id);
}