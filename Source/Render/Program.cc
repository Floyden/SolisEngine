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

    int Result = GL_FALSE;
	int InfoLogLength;

    glGetShaderiv(vsId, GL_COMPILE_STATUS, &Result);
	glGetShaderiv(vsId, GL_INFO_LOG_LENGTH, &InfoLogLength);
	if ( InfoLogLength > 0 ){
		std::vector<char> VertexShaderErrorMessage(InfoLogLength+1);
		glGetShaderInfoLog(vsId, InfoLogLength, NULL, &VertexShaderErrorMessage[0]);
        std::cout << VertexShaderErrorMessage.data() << std::endl;
	}

    auto fsSrc = fs.c_str();
    glShaderSource(fsId, 1, &fsSrc, nullptr);
    glCompileShader(fsId);

    glGetShaderiv(fsId, GL_COMPILE_STATUS, &Result);
	glGetShaderiv(fsId, GL_INFO_LOG_LENGTH, &InfoLogLength);
	if ( InfoLogLength > 0 ){
		std::vector<char> VertexShaderErrorMessage(InfoLogLength+1);
		glGetShaderInfoLog(fsId, InfoLogLength, NULL, &VertexShaderErrorMessage[0]);
        std::cout << VertexShaderErrorMessage.data() << std::endl;
	}

    mHandle = glCreateProgram();
    glAttachShader(mHandle, vsId);
    glAttachShader(mHandle, fsId);
    glLinkProgram(mHandle);

    glDetachShader(mHandle, vsId);
	glDetachShader(mHandle, fsId);
	
	glDeleteShader(vsId);
	glDeleteShader(fsId);
}

} // namespace Solis