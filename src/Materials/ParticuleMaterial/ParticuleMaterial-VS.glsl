#version 460



uniform mat4 Model;
uniform mat4 ViewProj;
uniform vec3 PosCam;
uniform vec3 PosLum;
uniform float Time;

 out gl_PerVertex {
        vec4 gl_Position;
        float gl_PointSize;
        float gl_ClipDistance[];
    };

layout(std430, binding = 0) buffer ParticleBuffer {
    vec4 particulesPositions[];
};


layout (location = 0) in vec3 Position;
layout (location = 2) in vec3 Normal;
layout (location = 3) in vec3 texCoords;


out VTF {
vec3 vL;
vec3 vV;
vec3 vN;
vec3 v_Color;
vec2 uv;

};



void main()
{
    /*TP2 : Trouver la nouvelle position (ajouter la valeur de position de la particule a chaque sommet) : L'indice de la particule est gl_InstanceID */
    vec3 Pos = Position + particulesPositions[gl_InstanceID].xyz;


	gl_Position = ViewProj * Model * vec4(Pos,1.0);

 	
 	vN =normalize(Normal);

    vL = (PosLum-Pos);
    vV = (PosCam-Pos);
    uv = texCoords.xy;

  

}
