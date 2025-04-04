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

const int MaxParticulesInCell = 25;
ivec3 gridSize = ivec3(20, 20, 20);

struct ParticuleNode {
    int id;
    int next;  // Pointer to next object (-1 if end of list)
};

layout(std430, binding = 4) buffer ParticulesBuffer {
    ParticuleNode ParticulesNodeBuffer[];
};

layout(std430, binding = 5) buffer GridBuffer {
    int gridHead[];  // Stores the first object index per cell (-1 if empty)
};

int getGridIndex(vec4 pos) {
    ivec4 int_pos = ivec4(pos);
    return int_pos.x + gridSize.x * (int_pos.y + gridSize.y * int_pos.z);
}

void removeParticuleFromGrid(int objIndex, vec4 pos) {
    int cellIndex = getGridIndex(pos);

    int prev = -1;
    int curr = gridHead[cellIndex];

    while (curr != -1) {
        if (curr == objIndex) {
            if (prev == -1) {
                // Object is the first in the list, update gridHead
                gridHead[cellIndex] = ParticulesNodeBuffer[curr].next;
            } else {
                // Skip the current object
                ParticulesNodeBuffer[prev].next = ParticulesNodeBuffer[curr].next;
            }
            ParticulesNodeBuffer[curr].next = -1; // Clear its next pointer
            return;
        }
        prev = curr;
        curr = ParticulesNodeBuffer[curr].next;
    }
}

void insertParticule(int currentHeadPartIndex, vec4 pos, uint id) {
    int cellIndex = getGridIndex(pos);

    // Assign new ID

    // Ensure this particle's `next` pointer is -1 initially
    //ParticulesNodeBuffer[headPartIndex].next = -1;

    // Add to the front of the linked list
    if (ParticulesNodeBuffer[currentHeadPartIndex].next != -1) {
        ParticulesNodeBuffer[currentHeadPartIndex].next = gridHead[cellIndex];  // Link to old head
    }

    gridHead[cellIndex] = int(id);  // Update grid head to the new object
}


void moveObject(int headPartIndex, vec4 oldPos, vec4 newPos, uint id) {
    removeParticuleFromGrid(headPartIndex, oldPos);
    insertParticule(headPartIndex, newPos, id);
}

int[MaxParticulesInCell] getObjectsInCell(vec4 position) {
    int cellIndex = getGridIndex(position);
    int headIndex = gridHead[cellIndex];
    int objIndex = headIndex;

    int objectIds[MaxParticulesInCell];
    int i = 0;

    for (int j = 0; j < MaxParticulesInCell; j++) {
        objectIds[j] = -1;
    }

    while (objIndex != -1 || i < MaxParticulesInCell) {
        ParticuleNode part = ParticulesNodeBuffer[objIndex];

        objectIds[i] = part.id;
        i++;
        
        objIndex = part.next; // Move to next object in the list
    }
    return objectIds;
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
    //Colldie avec tout les cotés
    ColliderWithPlane(vec4(0, 1, 0, 0), vec4(0, -10, 0, 0), V, P);  //Bottom
    ColliderWithPlane(vec4(0, -1, 0, 0), vec4(0, 10, 0, 0), V, P);  //Top
    
    ColliderWithPlane(vec4(1, 0, 0, 0), vec4(-10, 0, 0, 0), V, P);  //Left
    ColliderWithPlane(vec4(-1, 0, 0, 0), vec4(10, 0, 0, 0), V, P);  //Right
    
    ColliderWithPlane(vec4(0, 0, 1, 0), vec4(0, 0, -10, 0), V, P);  //Back
    ColliderWithPlane(vec4(0, 0, -1, 0), vec4(0, 0, 10, 0), V, P);  //Front
}

void CollideWithLocalSpheres(uint id, inout vec4 V, inout vec4 P) {

    int objectIds[MaxParticulesInCell];
    objectIds = getObjectsInCell(P);
    
    for(uint i = 0; i < NumParticules; ++i) {
        uint partId = i;//objectIds[i];
        if (i == id) continue;//|| partId == -1) continue;  //Dont check for self

        vec4 dir = Positiont[partId] - P;
        vec4 n = normalize(dir);
        float dist = length(dir);

        //collision?
        if (dist < SphereRadius) {
            //corriger pos
            float d = (SphereRadius - dist) * 0.5;
            P -= d * n;
            Positiont[partId] += d * n;

            vec4 Vi = Velocityt1[partId];

            vec4 ViPer = dot(Vi, n) * n;
            vec4 ViPar = Vi - ViPer;

            vec4 Vper = dot(V, n) * n;
            vec4 Vpar = V - Vper;

            //échanger vitesse per.
            V = Vpar + ViPer;               //Friction & impact??
            Velocityt1[partId] = ViPar + Vper;
        }
    }
}


vec3 getCellCoord(vec4 pos) {
    return vec3(floor(pos.x), floor(pos.y), floor(pos.z));
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
    
    int newCellIndex = getGridIndex(Positiont1[id]);
    if (newCellIndex != cellIndex) {
        moveObject(gridHead[cellIndex], Positiont[id], Positiont1[id], id);
    }
}