#include "Program.hh"
#include <vector>
#include <iostream>

namespace Solis
{

Program::~Program()
{
    if(mHandle)
        glDeleteProgram(mHandle);
}

void Program::SetUniform1f(const std::string& name, float value)
{
    auto loc = glGetUniformLocation(mHandle, name.c_str());
    glUniform1f(loc, value);
}

void Program::SetUniform2f(const std::string& name, const Vec2& value)
{
    auto loc = glGetUniformLocation(mHandle, name.c_str());
    glUniform2f(loc, value.x, value.y);
}

void Program::SetUniform3f(const std::string& name, const Vec3& value)
{
    auto loc = glGetUniformLocation(mHandle, name.c_str());
    glUniform3f(loc, value.x, value.y, value.z);
}

void Program::SetUniform4f(const std::string& name, const Vec4& value)
{
    auto loc = glGetUniformLocation(mHandle, name.c_str());
    glUniform4f(loc, value.x, value.y, value.z, value.w);
}

void Program::SetUniformMat4f(const std::string& name, const Matrix4& value)
{
    auto loc = glGetUniformLocation(mHandle, name.c_str());
    glUniformMatrix4fv(loc, 1, false, glm::value_ptr(value));
}

void Program::SetUniform1i(const std::string& name, int value)
{
    auto loc = glGetUniformLocation(mHandle, name.c_str());
    glUniform1i(loc, value);
}

void Program::SetUniform2i(const std::string& name, const Vec2i& value)
{
    auto loc = glGetUniformLocation(mHandle, name.c_str());
    glUniform2i(loc, value.x, value.y);
}

void Program::LoadFrom(const std::string& vs, const std::string& fs)
{
    auto vsId = glCreateShader(GL_VERTEX_SHADER);
    auto fsId = glCreateShader(GL_FRAGMENT_SHADER);

    auto vsSrc = vs.c_str();
    glShaderSource(vsId, 1, &vsSrc, nullptr);
    glCompileShader(vsId);

    int result = GL_FALSE;
	int infoLogLength;

    glGetShaderiv(vsId, GL_COMPILE_STATUS, &result);
	glGetShaderiv(vsId, GL_INFO_LOG_LENGTH, &infoLogLength);
	if ( infoLogLength > 0 ){
		std::vector<char> vertexShaderErrorMessage(infoLogLength+1);
		glGetShaderInfoLog(vsId, infoLogLength, NULL, &vertexShaderErrorMessage[0]);
        std::cout << vertexShaderErrorMessage.data() << std::endl;
	}

    auto fsSrc = fs.c_str();
    glShaderSource(fsId, 1, &fsSrc, nullptr);
    glCompileShader(fsId);

    glGetShaderiv(fsId, GL_COMPILE_STATUS, &result);
	glGetShaderiv(fsId, GL_INFO_LOG_LENGTH, &infoLogLength);
	if ( infoLogLength > 0 ){
		std::vector<char> fragmentShaderErrorMessage(infoLogLength+1);
		glGetShaderInfoLog(fsId, infoLogLength, NULL, &fragmentShaderErrorMessage[0]);
        std::cout << fragmentShaderErrorMessage.data() << std::endl;
	}

    mHandle = glCreateProgram();
    glAttachShader(mHandle, vsId);
    glAttachShader(mHandle, fsId);
    glLinkProgram(mHandle);

    glGetProgramiv(mHandle, GL_LINK_STATUS, &result);
	glGetProgramiv(mHandle, GL_INFO_LOG_LENGTH, &infoLogLength);
	if ( infoLogLength > 0 ){
		std::vector<char> programErrorMessage(infoLogLength+1);
		glGetProgramInfoLog(mHandle, infoLogLength, NULL, &programErrorMessage[0]);
        std::cout << programErrorMessage.data() << std::endl;
	}

    glDetachShader(mHandle, vsId);
	glDetachShader(mHandle, fsId);
	
	glDeleteShader(vsId);
	glDeleteShader(fsId);
}

} // namespace Solis