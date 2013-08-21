module dquick.renderer_3d.opengl.mesh;

import dquick.renderer_3d.opengl.renderer;
import dquick.renderer_3d.opengl.texture;
import dquick.renderer_3d.opengl.shader;
import dquick.renderer_3d.opengl.shader_program;
import dquick.renderer_3d.opengl.vbo;
import dquick.renderer_3d.opengl.util;
import dquick.renderer_3d.opengl.renderer;

import dquick.maths.color;

import derelict.opengl3.gl;

import std.stdio;

class Mesh
{
public:
	this()
	{
		create();

		indexes = new VBO!GLuint();
		vertices = new VBO!GLfloat();
		colors = new VBO!GLfloat();
		texCoords = new VBO!GLfloat();
	}

	~this()
	{
		destroy();
	}

	bool	setTexture(string filePath)
	{
		mTexture = dquick.renderer_3d.opengl.renderer.resourceManager.getResource!Texture(filePath);
		return true;
	}
	Texture	texture() {return mTexture;}

	void	setShader(Shader shader)
	{
		mShader = shader;

		mPositionAttribute = checkgl!glGetAttribLocation(mShader.getProgram(), cast(char*)("a_position"));
		mColorAttribute = checkgl!glGetAttribLocation(mShader.getProgram(), cast(char*)("a_color"));
		mTexcoordAttribute = checkgl!glGetAttribLocation(mShader.getProgram(), cast(char*)("a_texcoord"));
		mTextureUniform = checkgl!glGetUniformLocation(mShader.getProgram(), cast(char*)("u_texture"));
		mMDVMatrixUniform = checkgl!glGetUniformLocation(mShader.getProgram(), cast(char*)("u_modelViewProjectionMatrix"));
	}
	Shader	shader() {return mShader;}

	void			setShaderProgram(ShaderProgram program) {mShaderProgram = program;}
	ShaderProgram	shaderProgram() {return mShaderProgram;}

	VBO!GLuint		indexes;
	VBO!GLfloat		vertices;
	VBO!GLfloat		colors;
	VBO!GLfloat		texCoords;

	void	draw()
	{
/*		checkgl!glUseProgram(mShader.getProgram);

		glUniformMatrix4fv(mMDVInvertedMatrixUniform, 1, false, (Renderer.currentCamera().inverse() * Renderer.currentMDVMatrix).inverse().value_ptr);*/

		mShaderProgram.execute();

		glUniformMatrix4fv(mMDVMatrixUniform, 1, false, Renderer.currentMDVMatrix.value_ptr);

		// bind the texture and set the "tex" uniform in the fragment shader
		if (mTexture)
		{
			checkgl!glActiveTexture(GL_TEXTURE0);
			checkgl!glBindTexture(GL_TEXTURE_2D, mTexture.id());
			checkgl!glUniform1i(mTextureUniform, 0); //set to 0 because the texture is bound to GL_TEXTURE0
		}

		// Can be in a VAO
		{
			indexes.bind();
			vertices.bind();
			checkgl!glEnableVertexAttribArray(mPositionAttribute);
			checkgl!glVertexAttribPointer(mPositionAttribute, 3, GL_FLOAT, GL_FALSE, cast(GLsizei)(3 * GLfloat.sizeof), null + cast(GLvoid*)(0 * GLfloat.sizeof));
			colors.bind();
			checkgl!glEnableVertexAttribArray(mColorAttribute);
			checkgl!glVertexAttribPointer(mColorAttribute, 4, GL_FLOAT, GL_FALSE, cast(GLsizei)(4 * GLfloat.sizeof), null + cast(GLvoid*)(0 * GLfloat.sizeof));
			texCoords.bind();
			checkgl!glEnableVertexAttribArray(mTexcoordAttribute);
			checkgl!glVertexAttribPointer(mTexcoordAttribute, 2, GL_FLOAT, GL_FALSE, cast(GLsizei)(2 * GLfloat.sizeof), null + cast(GLvoid*)(0 * GLfloat.sizeof));
		}

		// draw the VBOs
		checkgl!glDrawElements(GL_TRIANGLES, cast(GLsizei)indexes.length, GL_UNSIGNED_INT, null);

		// unbind VBOs, the program and the texture
		indexes.unbind();	// One unbind per type
		vertices.unbind();	// One unbind per type
		checkgl!glBindTexture(GL_TEXTURE_2D, mBadId);
		checkgl!glBindBuffer(GL_ARRAY_BUFFER, mBadId);
		checkgl!glUseProgram(mBadId);
	}

private:
	void	create()
	{
/*		mShader = dquick.renderer_3d.opengl.renderer.resourceManager.getResource!Shader("dquick/shaders/rectangle");

		mMDVInvertedMatrixUniform = checkgl!glGetUniformLocation(mShader.getProgram(), cast(char*)("u_modelViewProjectionInvertedMatrix"));*/
	}

	void	destroy()
	{
		dquick.renderer_3d.opengl.renderer.resourceManager.releaseResource(mTexture);
		dquick.renderer_3d.opengl.renderer.resourceManager.releaseResource(indexes);
		mTexture = null;
		indexes = null;
//		.destroy(mShader);
	}

	static const GLuint		mBadId = 0;

	GLint					mPositionAttribute;
	GLint					mColorAttribute;
	GLint					mTexcoordAttribute;
	GLint					mTextureUniform;
	GLint					mMDVMatrixUniform;

	Shader					mShader;
	ShaderProgram			mShaderProgram;
	Texture					mTexture;			// TODO move to Material
}