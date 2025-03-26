
#include "ParticuleMaterial.h"
#include "Node.h"
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/random.hpp>

ParticuleMaterial::ParticuleMaterial(std::string name) :
	MaterialGL(name)
{

	vp = new GLProgram(MaterialPath + "ParticuleMaterial/ParticuleMaterial-VS.glsl", GL_VERTEX_SHADER);
	fp = new GLProgram(MaterialPath + "ParticuleMaterial/ParticuleMaterial-FS.glsl", GL_FRAGMENT_SHADER);

	m_ProgramPipeline->useProgramStage(vp, GL_VERTEX_SHADER_BIT);
	m_ProgramPipeline->useProgramStage(fp, GL_FRAGMENT_SHADER_BIT);


	l_ViewProj = glGetUniformLocation(vp->getId(), "ViewProj");
	l_Model = glGetUniformLocation(vp->getId(), "Model");
	l_PosLum = glGetUniformLocation(vp->getId(), "PosLum");
	l_PosCam = glGetUniformLocation(vp->getId(), "PosCam");



	l_Phong = glGetUniformLocation(fp->getId(), "Phong");
	l_Albedo = glGetUniformLocation(fp->getId(), "diffuseAlbedo");
	l_specColor = glGetUniformLocation(fp->getId(), "specularColor");


	param.albedo = glm::vec3(0.2, 0.7, 0.8);
	param.coeff = glm::vec4(0.2,0.8,1.0,100.0);
	param.specularColor = glm::vec3(1.0);

	glCreateQueries(GL_TIME_ELAPSED, 1, &mQueryTimeElapsed);
    mSimTime = 0;
	


	/**************************TP 2 ****************************/
	// Create SSBO  : glCreateBuffers (position,velocité, !!couleur (?)!!) 
	// Populate SSB : glNamedBufferStorage - Pensez a utiliser des vec4 pour eviter les erreurs d'alignements
	// Repartir les particules aléatoirement (utiliser glm::sphericalRand)
	// Créer le compute shader

	/**********************************************************/

    cp = new GLProgram(MaterialPath + "ParticuleMaterial/ParticuleMaterial-CS.glsl", GL_COMPUTE_SHADER);
    //m_ProgramPipeline->useProgramStage(cp, GL_COMPUTE_SHADER_BIT);
    l_GravityDir = glGetUniformLocation(cp->getId(), "GravityDir");
    l_Mass = glGetUniformLocation(cp->getId(), "Mass");
    l_DeltaTime = glGetUniformLocation(cp->getId(), "DeltaTime");
    l_PNum = glGetUniformLocation(cp->getId(), "NumParticules");
    glProgramUniform1i(cp->getId(), l_PNum, PARTICULENUMBER);

	const int bufferSize = sizeof(glm::vec4) * PARTICULENUMBER;

	glCreateBuffers(2, m_Positions);
    glm::vec4 tempPos[PARTICULENUMBER];
    for (int i = 0; i < PARTICULENUMBER; i++) {

        tempPos[i] = glm::vec4(glm::sphericalRand(5.0f), 0);
	}
    glNamedBufferStorage(m_Positions[0], bufferSize, tempPos, GL_DYNAMIC_STORAGE_BIT);
    glNamedBufferStorage(m_Positions[1], bufferSize, tempPos, GL_DYNAMIC_STORAGE_BIT);

    glCreateBuffers(2, m_Velocities);
    glm::vec4 tempVelo[PARTICULENUMBER];
    for (int i = 0; i < PARTICULENUMBER; i++) {
        tempVelo[i] = glm::vec4(0);
    }
    glNamedBufferStorage(m_Velocities[0], bufferSize, tempVelo, GL_DYNAMIC_STORAGE_BIT);
    glNamedBufferStorage(m_Velocities[1], bufferSize, tempVelo, GL_DYNAMIC_STORAGE_BIT);

	l_Time = glGetUniformLocation(vp->getId(), "Time");

	physik.mass = 0.1f;
    physik.deltaTime = 0.01f;

	updateSimulationParameters();
	updatePhong();
}

ParticuleMaterial::~ParticuleMaterial()
{

}

void ParticuleMaterial::render(Node* o)
{

	/**************************TP 2 ****************************/
	// Lier les SSBO pour le rendu : glBindBufferBase
	/**********************************************************/
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, m_Positions[bufferBindFlag ? 0 : 1]);

	m_ProgramPipeline->bind();

	// Afficher en utilisant l'instanciation - Affiche N modeles
	o->drawGeometryInstanced(GL_TRIANGLES, PARTICULENUMBER);

	m_ProgramPipeline->release();
}
void ParticuleMaterial::animate(Node* o, const float elapsedTime)
{

	glm::mat4 viewproj = Scene::getInstance()->camera()->getProjectionMatrix() * Scene::getInstance()->camera()->getViewMatrix();

	glProgramUniformMatrix4fv(vp->getId(), l_ViewProj, 1, GL_FALSE, glm::value_ptr(viewproj));
	glProgramUniformMatrix4fv(vp->getId(), l_Model, 1, GL_FALSE, glm::value_ptr(o->frame()->getModelMatrix()));
	glProgramUniform3fv(vp->getId(), l_PosLum, 1,  glm::value_ptr(Scene::getInstance()->getNode("Light")->frame()->convertPtTo(glm::vec3(0.0,0.0,0.0),o->frame())));
	glProgramUniform3fv(vp->getId(), l_PosCam, 1, glm::value_ptr(Scene::getInstance()->camera()->frame()->convertPtTo(glm::vec3(0.0, 0.0, 0.0), o->frame())));

	auto now_time = std::chrono::high_resolution_clock::now();
	auto timevar = now_time.time_since_epoch();
	float millis = 0.001f*std::chrono::duration_cast<std::chrono::milliseconds>(timevar).count();
	
	/*Direction du vecteur up dans le rep�re de l'objet. A utiliser pour d�finir la direction de la force de gravit�*/
	glm::vec3 gravityDir = Scene::getInstance()->getSceneNode()->frame()->convertDirTo(glm::vec3(0.0, -1.0, 0.0), o->frame());
    /**************************TP 2 ****************************/
    // Envoyer la direction de la gravité au compute shader
    /**********************************************************/
    glProgramUniform3fv(cp->getId(), l_GravityDir, 1, glm::value_ptr(gravityDir));
    bufferBindFlag = !bufferBindFlag;

	simulation();
}

void ParticuleMaterial::simulation()
{

	glBeginQuery(GL_TIME_ELAPSED, mQueryTimeElapsed);

	/**************************TP 2 ****************************/
    // Lier les SSBOs : glBindBufferBase
    // Lancer le compute shader :  glDispatchCompute(X,Y,Z);
    /**********************************************************/
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, bufferBindFlag ? 0 : 1, m_Positions[0]);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, !bufferBindFlag ? 0 : 1, m_Positions[1]);

    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, bufferBindFlag ? 2 : 3, m_Velocities[0]);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, !bufferBindFlag ? 2 : 3, m_Velocities[1]);

	glUseProgram(cp->getId());
    int nbWorkGroup = (PARTICULENUMBER / 32) + 1;
	glDispatchCompute(nbWorkGroup,1,1);

    glUseProgram(NULL);
    glEndQuery(GL_TIME_ELAPSED);
    GLuint64 result = static_cast<GLuint64>(0);
    glGetQueryObjectui64v(mQueryTimeElapsed, GL_QUERY_RESULT, &result);
    mSimTime = result;
}


void ParticuleMaterial::updatePhong()
{
	glProgramUniform4fv(fp->getId(), l_Phong, 1, glm::value_ptr(glm::vec4(param.coeff)));
	glProgramUniform3fv(fp->getId(), l_Albedo, 1, glm::value_ptr(param.albedo));
	glProgramUniform3fv(fp->getId(), l_specColor, 1, glm::value_ptr(param.specularColor));
}

void ParticuleMaterial::updateSimulationParameters()
{
    /**************************TP 2 ****************************/
    // Mettre a jour les parmetres de la simulation
    /**********************************************************/

    glProgramUniform1fv(cp->getId(), l_Mass, 1, &physik.mass);
    glProgramUniform1fv(cp->getId(), l_DeltaTime, 1, &physik.deltaTime);
}

void ParticuleMaterial::displayInterface()
{

	if (ImGui::TreeNode("Physical parameters"))
	{
        ImGui::BeginGroup();

        ImGui::Text("Simulaion time : %f ms/frame", (mSimTime * 1.e-6));
			
			bool upd = false;
            upd = ImGui::SliderFloat("Particule", &physik.mass, 0.1f, 10.0f, "Mass = %.3f") || upd;
            upd = ImGui::SliderFloat("deltaTime", &physik.deltaTime, 0.0f, 0.2f, "DeltaTime = %.3f") || upd;
			
			ImGui::EndGroup();
			ImGui::Separator();
			ImGui::Spacing();

			ImGui::TreePop();

			if (upd)
                updateSimulationParameters();
	}
	if (ImGui::TreeNode("PhongParameters"))
	{
	bool upd = false;
		upd = ImGui::SliderFloat("ambiant", &param.coeff.x, 0.0f, 1.0f, "ambiant = %.2f") || upd;
		upd = ImGui::SliderFloat("diffuse", &param.coeff.y, 0.0f, 1.0f, "diffuse = %.2f") || upd;
		upd = ImGui::SliderFloat("specular", &param.coeff.z, 0.0f, 2.0f, "specular = %.2f") || upd;
		upd = ImGui::SliderFloat("exposant", &param.coeff.w, 0.1f, 200.0f, "exposant = %f") || upd;
		ImGui::PushItemWidth(200.0f);
		upd = ImGui::ColorPicker3("Albedo", glm::value_ptr(param.albedo)) || upd;;
		ImGui::SameLine();
		upd = ImGui::ColorPicker3("Specular Color", glm::value_ptr(param.specularColor)) || upd;;
		ImGui::PopItemWidth();
		if (upd)
			updatePhong();
		ImGui::TreePop();
	}


}




