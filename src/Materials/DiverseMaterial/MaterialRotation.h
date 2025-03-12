

#ifndef _MATERIALROTATION_
#define _MATERIALROTATION_


#include "MaterialGL.h"

class MaterialRotation : public MaterialGL
{
	public :

		//Attributs
		
		//Constructeur-Destructeur

		/**
			Constructeur de la classe � partir du nom du mat�riau 
			@param name : nom du mat�riau
		*/
		MaterialRotation(string name="");

		/**
			Destructeur de la classe
		*/
		~MaterialRotation();

		//M�thodes

		/**
			M�thode virtuelle qui est appel�e pour faire le rendu d'un objet en utilisant ce mat�riau
			@param o : Node/Objet pour lequel on veut effectuer le rendu
		*/
		virtual void render(Node *o);

		/**
			M�thode virtuelle qui est appel�e pour modifier une valeur d'un param�tre n�cessaire pour le rendu
			@param o : Node/Objet concern� par le rendu
			@param elapsedTime : temps
		*/
		virtual void animate(Node* o, const float elapsedTime);


		virtual void displayInterface() ;

		
	protected :
		GLProgram* vp;
		GLProgram* fp;

		bool rot;
		float rspeed;

		GLuint l_ViewProj, l_Model;
};

#endif