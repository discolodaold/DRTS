module glutil;

import tango.io.Stdout;

import derelict.util.exception;

import derelict.sdl.sdl;
import derelict.sdl.image;
import derelict.opengl.gl;
import derelict.opengl.extension.ext.framebuffer_object;
import                 extension.ext.direct_state_access;
import derelict.opengl.glu;

import util : toStringz, Vec4D;

enum MinFilter {
	nearest = GL_NEAREST,
	linear = GL_LINEAR,
	nearest_mipmap_nearest = GL_NEAREST_MIPMAP_NEAREST,
	linear_mipmap_nearest = GL_LINEAR_MIPMAP_NEAREST,
	nearest_mipmap_linear = GL_NEAREST_MIPMAP_LINEAR,
	linear_mipmap_linear = GL_LINEAR_MIPMAP_LINEAR,
}
enum MagFilter {
	nearest = GL_NEAREST,
	linear = GL_LINEAR
}
enum Wrap {
	clamp = GL_CLAMP,
	clamp_to_edge = GL_CLAMP_TO_EDGE,
	mirrored_repeat = GL_MIRRORED_REPEAT,
	repeat = GL_REPEAT
}
enum Blend {
	zero = GL_ZERO,
	one = GL_ONE,
	src_color = GL_SRC_COLOR,
	one_minus_src_color = GL_ONE_MINUS_SRC_COLOR,
	dst_color = GL_DST_COLOR,
	one_minus_dst_color = GL_ONE_MINUS_DST_COLOR,
	src_alpha = GL_SRC_ALPHA,
	one_minus_src_alpha = GL_ONE_MINUS_SRC_ALPHA,
	dst_alpha = GL_DST_ALPHA,
	one_minus_dst_alpha = GL_ONE_MINUS_DST_ALPHA,
	constant_color = GL_CONSTANT_COLOR,
	one_minus_constant_color = GL_ONE_MINUS_CONSTANT_COLOR,
	constant_alpha = GL_CONSTANT_ALPHA,
	one_minus_constant_alpha = GL_ONE_MINUS_CONSTANT_ALPHA,
	src_alpha_saturate = GL_SRC_ALPHA_SATURATE
}
struct BlendFunc {
	Blend sfactor;
	Blend dfactor;
}
enum CubeMapSide {
	positive_x = GL_TEXTURE_CUBE_MAP_POSITIVE_X,
	negative_x = GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
	positive_y = GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
	negative_y = GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
	positive_z = GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
	negative_z = GL_TEXTURE_CUBE_MAP_NEGATIVE_Z
}
enum Frequency {
	Stream,
	Static,
	Dynamic
}
enum Nature {
	Draw,
	Read,
	Copy
}

private abstract class GLObject {
	protected GLuint m_id;
	public GLuint id() {
		return m_id;
	}

	bool isBuffer(){
		return glIsBuffer(m_id) == GL_TRUE;
	}
	bool isList() {
		return glIsList(m_id) == GL_TRUE;
	}
	bool isProgram() {
		return glIsProgram(m_id) == GL_TRUE;
	}
	bool isQuery() {
		return glIsQuery(m_id) == GL_TRUE;
	}
	bool isShader() {
		return glIsShader(m_id) == GL_TRUE;
	}
	bool isTexture() {
		return glIsTexture(m_id) == GL_TRUE;
	}
	bool isRenderbuffer() {
		return glIsRenderbufferEXT(m_id) == GL_TRUE;
	}
	bool isFramebuffer() {
		return glIsFramebufferEXT(m_id) == GL_TRUE;
	}
}

public class GLException : Exception {
	public this(char[] msg) {
		super(msg);
	}
}

struct RGBA {
	ubyte r = 255;
	ubyte g = 255;
	ubyte b = 255;
	ubyte a = 255;

	static RGBA opCall(ubyte[] _colors ...) {
		RGBA rgba;
		rgba.ptr[0 .. _colors.length] = _colors[0 .. _colors.length];
		return rgba;
	}
	
	static RGBA opCall(Vec4D _colors) {
		_colors = _colors * 4;
		
		ubyte ftoub(float s) {
			if(s > 255.0) return 255;
			if(s < 0.0  ) return 0;
			return cast(ubyte)s;
		}
	
		return RGBA(
			ftoub(_colors.x),
			ftoub(_colors.y),
			ftoub(_colors.z),
			ftoub(_colors.w)
		);	
	}

	ubyte* ptr() {
		return cast(ubyte*)this;
	}

	RGBA opMul(float s) {
		return RGBA(Vec4D(r * s, g * s, b * s, a * s));
	}

	RGBA opAdd(RGBA other) {
		return RGBA(r + other.r, g + other.g, b + other.b, a + other.a);
	}
}

final class Image2D {
	private SDL_Surface* m_surface;

	public ubyte* ptr() {
		return cast(ubyte*)m_surface.pixels;
	}

	public uint height() {
		return m_surface.h;
	}

	public uint width() {
		return m_surface.w;
	}

	public this(char[] path) {
		m_surface = IMG_Load(toStringz("../base/" ~ path));
	}

	public this(uint width, uint height) {
		m_surface = SDL_CreateRGBSurface(SDL_SWSURFACE, width, height, 32, 0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000);
	}

	public RGBA opIndex(uint x, uint y) {
		uint pixel;
		ubyte* d = ptr + (y * m_surface.pitch) + (x * bpp);
		switch(bpp) {
		case 3:
			if(SDL_BYTEORDER == SDL_BIG_ENDIAN)
				pixel = d[0] << 16 | d[1] << 8 | d[2];
			else
				pixel = d[0] | d[1] << 8 | d[2] << 16;
			break;
		case 4:
			pixel = *cast(uint*)d;
			break;
		}
		ubyte r, g, b, a;
		SDL_GetRGBA(pixel, m_surface.format, &r, &g, &b, &a);
		return RGBA(r, g, b, a);
	}

	public RGBA opIndexAssign(RGBA rgba, uint x, uint y) {
		uint pixel = SDL_MapRGBA(m_surface.format, rgba.r, rgba.g, rgba.b, rgba.a);
		ubyte* d = ptr + (y * m_surface.pitch) + (x * bpp);
		switch(bpp) {
		case 3:
			if(SDL_BYTEORDER == SDL_BIG_ENDIAN) {
				d[0] = (pixel >> 16) & 0xff;
				d[1] = (pixel >> 8) & 0xff;
				d[2] = pixel & 0xff;
			} else {
				d[0] = pixel & 0xff;
				d[1] = (pixel >> 8) & 0xff;
				d[2] = (pixel >> 16) & 0xff;
			}
			break;
		case 4:
			*(cast(uint*)d) = pixel;
			break;
		}
		return rgba;
	}

	int bpp() {
		return m_surface.format.BytesPerPixel;
	}

	GLuint type() {
		switch(bpp) {
		case 3:
			return (m_surface.format.Rmask == 0x000000ff) ? GL_RGB : GL_BGR;
		case 4:
			return (m_surface.format.Rmask == 0x000000ff) ? GL_RGBA : GL_BGRA;
		}
	}
}

private abstract class GLTexture : GLObject {
	this(MinFilter _min = MinFilter.nearest_mipmap_linear, MagFilter _mag = MagFilter.linear) {
		glGenTextures(1, &m_id);
		this.minFilter = _min;
		this.magFilter = _mag;
	}

	this(GLuint _id, MinFilter _min = MinFilter.nearest_mipmap_linear, MagFilter _mag = MagFilter.linear) {
		m_id = _id;
		this.minFilter = _min;
		this.magFilter = _mag;
	}

	~this() {
		glDeleteTextures(1, &m_id);
	}

	public abstract GLuint type();

	private void bind() {
		glBindTexture(type, m_id);
	}

	private V param_ri(V, GLuint P)() {
		bind();
		GLint i;
		glGetTexParameteriv(type, P, &i);
		return cast(V)i;
	}
	private void param_wi(V, GLuint P)(V i) {
		bind();
		glTexParameteriv(type, P, cast(GLint*)&i);
	}

	public alias param_ri!(MinFilter, GL_TEXTURE_MIN_FILTER) minFilter;
	public alias param_wi!(MinFilter, GL_TEXTURE_MIN_FILTER) minFilter;

	public alias param_ri!(MagFilter, GL_TEXTURE_MAG_FILTER) magFilter;
	public alias param_wi!(MagFilter, GL_TEXTURE_MAG_FILTER) magFilter;

	public alias param_ri!(int, GL_TEXTURE_MIN_LOD) minLOD;
	public alias param_wi!(int, GL_TEXTURE_MIN_LOD) minLOD;

	public alias param_ri!(int, GL_TEXTURE_MAX_LOD) maxLOD;
	public alias param_wi!(int, GL_TEXTURE_MAX_LOD) maxLOD;

	public alias param_ri!(uint, GL_TEXTURE_BASE_LEVEL) baseLevel;
	public alias param_wi!(uint, GL_TEXTURE_BASE_LEVEL) baseLevel;

	public alias param_ri!(uint, GL_TEXTURE_MAX_LEVEL) maxLevel;
	public alias param_wi!(uint, GL_TEXTURE_MAX_LEVEL) maxLevel;

	public alias param_ri!(bool, GL_GENERATE_MIPMAP) generateMipmap;
	public alias param_wi!(bool, GL_GENERATE_MIPMAP) generateMipmap;
}

public class GLTexture2D : GLTexture {
	GLuint type() {
		return GL_TEXTURE_2D;
	}

	uint height() {
		GLint d;
		glGetTexLevelParameteriv(type, 0, GL_TEXTURE_HEIGHT, &d);
		return d;
	}
	public alias param_ri!(Wrap, GL_TEXTURE_WRAP_T) wrapT;
	public alias param_wi!(Wrap, GL_TEXTURE_WRAP_T) wrapT;

	uint width() {
		GLint d;
		glGetTexLevelParameteriv(type, 0, GL_TEXTURE_WIDTH, &d);
		return d;
	}
	public alias param_ri!(Wrap, GL_TEXTURE_WRAP_S) wrapS;
	public alias param_wi!(Wrap, GL_TEXTURE_WRAP_S) wrapS;

	public void resize(uint _width, uint _height) {
		bind();
		glTexImage2D(type, 0, GL_RGBA8, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
	}

	public void image(Image2D img) {
		bind();
		glTexImage2D(type, 0, img.bpp, img.width, img.height, 0, img.type, GL_UNSIGNED_BYTE, img.ptr);
	}

	public Image2D image() {
		bind();
		Image2D img = new Image2D(width, height);
		glGetTexImage(type, 0, GL_RGBA, GL_UNSIGNED_BYTE, img.ptr);
		return img;
	}
}

private class GLShader : GLObject {
	this(GLuint _type) {
		m_id = glCreateShader(_type);
	}

	this(GLuint _type, GLuint _id) {
		m_id = _id;
	}

	~this() {
		glDeleteShader(m_id);
	}

	public GLuint type() {
		GLint i;
		glGetShaderiv(m_id, GL_SHADER_TYPE, &i);
		return i;
	}

	public char[] source() {
		GLint i;
		GLsizei length;
		glGetShaderiv(m_id, GL_SHADER_SOURCE_LENGTH, &i);
		char[] src = new char[](i);
		glGetShaderInfoLog(m_id, i, &length, src.ptr);
		return length > 0 ? src : "";
	}
	public void source(char[] source) {
		char* sourcez = toStringz(source);
		glShaderSource(m_id, 1, &sourcez, null);
	}

	public void compile() {
		glCompileShader(m_id);

		GLint i;
		glGetShaderiv(m_id, GL_COMPILE_STATUS, &i);
		if(i == GL_FALSE) {
			GLsizei len;
			glGetShaderiv(m_id, GL_INFO_LOG_LENGTH, &i);
			char[] log = new char[](i);
			glGetShaderInfoLog(m_id, i, &len, log.ptr);
			throw new GLException("shader compile error:" \n ~ (len > 0 ? log : ""));
		}
	}
}

public class GLProgram : GLObject {
	this() {
		m_id = glCreateProgram();
	}

	~this() {
		glDeleteProgram(m_id);
	}

	private struct Uniform {
		GLint location;
		GLint size;
		GLenum type;
	}
	private Uniform[char[]] m_uniforms;

	public float[] uniform(char[] name) {
		Uniform u = m_uniforms[name];
		float[] f = new float[](u.size * (u.type == GL_FLOAT) ? 1 :
										 (u.type == GL_FLOAT_VEC2) ? 2 :
										 (u.type == GL_FLOAT_VEC3) ? 3 : 4);
		glGetUniformfv(id, u.location, f.ptr);
		return f;
	}
	public void uniform(char[] name, float[] f ...) {
		Uniform u = m_uniforms[name];
		switch(u.type) {
		case GL_FLOAT:
			assert(u.size >= f.length);
			glUniform1fv(u.location, f.length, f.ptr);
			break;
		case GL_FLOAT_VEC2:
			assert(u.size >= f.length/2);
			glUniform2fv(u.location, f.length/2, f.ptr);
			break;
		case GL_FLOAT_VEC3:
			assert(u.size >= f.length/3);
			glUniform3fv(u.location, f.length/3, f.ptr);
			break;
		case GL_FLOAT_VEC4:
			assert(u.size >= f.length/4);
			glUniform4fv(u.location, f.length/4, f.ptr);
			break;
		}
	}
	public int[] uniform(char[] name) {
		Uniform u = m_uniforms[name];
		int[] i = new int[](u.size * (u.type == GL_FLOAT) ? 1 :
		                             (u.type == GL_FLOAT_VEC2) ? 2 :
		                             (u.type == GL_FLOAT_VEC3) ? 3 : 4);
		glGetUniformiv(id, u.location, i.ptr);
		return i;
	}
	public void uniform(char[] name, int[] i ...) {
		Uniform u = m_uniforms[name];
		switch(u.type) {
		case GL_INT:
		case GL_SAMPLER_1D:
		case GL_SAMPLER_2D:
		case GL_SAMPLER_3D:
		case GL_SAMPLER_CUBE:
		case GL_SAMPLER_1D_SHADOW:
		case GL_SAMPLER_2D_SHADOW:
			assert(u.size >= i.length);
			glUniform1iv(u.location, i.length, i.ptr);
			break;
		case GL_INT_VEC2:
			assert(u.size >= i.length/2);
			glUniform2iv(u.location, i.length/2, i.ptr);
			break;
		case GL_INT_VEC3:
			assert(u.size >= i.length/3);
			glUniform3iv(u.location, i.length/3, i.ptr);
			break;
		case GL_INT_VEC4:
			assert(u.size >= i.length/4);
			glUniform4iv(u.location, i.length/4, i.ptr);
			break;
		}
	}

	private struct Attribute {
		GLint location;
		GLint size;
		GLenum type;
	}
	private Attribute[char[]] m_attributes;

	public GLShader vertex(GLShader shader) {
		assert(shader.type == GL_VERTEX_SHADER);
		glAttachShader(m_id, shader.id);
		return shader;
	}
	public GLShader vertex(char[] source) {
		GLShader shader = new GLShader(GL_VERTEX_SHADER);
		shader.source = source;
		shader.compile();
		return this.vertex(shader);
	}

	public GLShader fragment(GLShader shader) {
		assert(shader.type == GL_FRAGMENT_SHADER);
		glAttachShader(m_id, shader.id);
		return shader;
	}
	public GLShader fragment(char[] source) {
		GLShader shader = new GLShader(GL_FRAGMENT_SHADER);
		shader.source = source;
		shader.compile();
		return this.fragment(shader);
	}

	public void link() {
		glLinkProgram(m_id);

		GLint i, size, l;
		GLenum type;
		GLsizei len;

		glGetProgramiv(m_id, GL_LINK_STATUS, &i);
		if(i == GL_FALSE) {
			glGetProgramiv(m_id, GL_INFO_LOG_LENGTH, &i);
			char[] log = new char[](i);
			glGetProgramInfoLog(m_id, i, &len, log.ptr);
			throw new GLException("program link error:" \n ~ ((len > 0) ? log : ""));
		}

		char[] uniform_name, attrib_name;
		glGetProgramiv(m_id, GL_ACTIVE_UNIFORM_MAX_LENGTH, &i);
		uniform_name.length = i + 1;

		glGetProgramiv(m_id, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &i);
		attrib_name.length = i + 1;

		glGetProgramiv(m_id, GL_ACTIVE_UNIFORMS, &i);
		while(i--) {
			glGetActiveUniform(m_id, i, uniform_name.length, &len, &size, &type, uniform_name.ptr);
			l = glGetUniformLocation(m_id, uniform_name.ptr);
			if(l != -1)
				m_uniforms[uniform_name[0 .. len].dup] = Uniform(l, size, type);
		}
		m_uniforms.rehash;

		glGetProgramiv(m_id, GL_ACTIVE_ATTRIBUTES, &i);
		while(i--) {
			glGetActiveAttrib(m_id, i, attrib_name.length, &len, &size, &type, attrib_name.ptr);
			l = glGetAttribLocation(m_id, attrib_name.ptr);
			if(l != -1)
				m_attributes[attrib_name[0 .. len].dup] = Attribute(l, size, type);
		}
		m_attributes.rehash;
	}

	GLShader[] shaders() {
		GLint i;
		GLsizei length;
		glGetProgramiv(m_id, GL_ATTACHED_SHADERS, &i);
		GLuint[] shader_ids = new GLuint[](i);
		glGetAttachedShaders(m_id, i, &length, shader_ids.ptr);
		GLShader[] shader_list;
		foreach(_id; shader_ids)
			shader_list ~= new GLShader(0, _id);
		return shader_list;
	}
}

public class GLBuffer : GLObject {
	this() {
		glGenBuffers(1, &m_id);
	}

	~this() {
		glDeleteBuffers(1, &m_id);
	}
}

public void glError() {
	GLenum error_code = glGetError();
	switch(error_code) {
	case GL_INVALID_ENUM:
		throw new GLException("GLenum argument out of range");
	case GL_INVALID_VALUE:
		throw new GLException("GLenum argument out of range");
	case GL_INVALID_OPERATION:
		throw new GLException("Operation illegal in current state");
	case GL_STACK_OVERFLOW:
		throw new GLException("Command would cause a stack overflow");
	case GL_STACK_UNDERFLOW:
		throw new GLException("Command would cause a stack underflow");
	case GL_OUT_OF_MEMORY:
		throw new GLException("Not enough memory left to execute command");
	default:
		break;
	}
}

/*
    boolean IsRenderbufferEXT(uint renderbuffer);
    void BindRenderbufferEXT(enum target, uint renderbuffer);
    void DeleteRenderbuffersEXT(sizei n, const uint *renderbuffers);
    void GenRenderbuffersEXT(sizei n, uint *renderbuffers);

    void RenderbufferStorageEXT(enum target, enum internalformat, sizei width, sizei height);

    void GetRenderbufferParameterivEXT(enum target, enum pname, int *params);
*/
/*
    boolean IsFramebufferEXT(uint framebuffer);
    void BindFramebufferEXT(enum target, uint framebuffer);
    void DeleteFramebuffersEXT(sizei n, const uint *framebuffers);
    void GenFramebuffersEXT(sizei n, uint *framebuffers);

    enum CheckFramebufferStatusEXT(enum target);

    void FramebufferTexture1DEXT(enum target, enum attachment, enum textarget, uint texture, int level);
    void FramebufferTexture2DEXT(enum target, enum attachment, enum textarget, uint texture, int level);
    void FramebufferTexture3DEXT(enum target, enum attachment, enum textarget, uint texture, int level, int zoffset);

    void FramebufferRenderbufferEXT(enum target, enum attachment, enum renderbuffertarget, uint renderbuffer);

    void GetFramebufferAttachmentParameterivEXT(enum target, enum attachment, enum pname, int *params);

    void GenerateMipmapEXT(enum target);
*/

private class GLFramebuffer : GLObject {
	this() {
		assert(EXTFramebufferObject.isEnabled, "no EXT_framebuffer_object");
		glGenFramebuffersEXT(1, &m_id);
	}

	~this() {
		glDeleteFramebuffersEXT(1, &m_id);
	}

	void attach(GLenum attachment)(GLTexture2D tex) {
		glState.framebuffer = this;
		glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, attachment, tex.type, tex.id, 0);
	}
	alias attach!(GL_COLOR_ATTACHMENT0_EXT) color0;
	alias attach!(GL_COLOR_ATTACHMENT1_EXT) color1;
	alias attach!(GL_COLOR_ATTACHMENT2_EXT) color2;
}

// an interface to the OpenGL state
private final class GLSTATE {
	// textures
	private struct GLTEXTUREUNIT {
		GLenum unit;
		GLenum tex_type;
		GLuint tex_id;

		void texture(GLTexture tex) {
			glActiveTexture(unit);
			if(tex) {
				tex_type = tex.type;
				glEnable(tex_type);
				if(tex_id != tex.id) {
					tex_id = tex.id;
					glBindTexture(tex_type, tex_id);
				}
			} else if(tex_type != GL_FALSE) {
				glDisable(tex_type);
				tex_type = GL_FALSE;
			}
		}
	}
	public GLTEXTUREUNIT[] tu;

	private GLTexture2D[char[]] m_textures2d;
	public GLTexture2D texture2D(char[] path) {
		if(!(path in m_textures2d)) {
			GLTexture2D tex = new GLTexture2D();
			tex.generateMipmap = true;
			tex.image = new Image2D(path);
			m_textures2d[path.dup] = tex;
		}
		return m_textures2d[path];
	}
	
	// lights
	private struct GLLIGHT {
		GLenum unit;

		void set(GLenum pname, uint size)(float[] s...) in { assert(s.length == size); } body { glLightfv(unit, pname, s.ptr); }
		float[] get(GLenum pname, uint size)() { float[] s; s.length = size; glGetLightfv(unit, pname, s.ptr); return s; }

		alias set!(GL_AMBIENT, 4) ambient;
		alias get!(GL_AMBIENT, 4) ambient;

		alias set!(GL_DIFFUSE, 4) diffuse;
		alias get!(GL_DIFFUSE, 4) diffuse;

		alias set!(GL_SPECULAR, 4) specular;
		alias get!(GL_SPECULAR, 4) specular;

		alias set!(GL_POSITION, 4) position;
		alias get!(GL_POSITION, 4) position;

		alias set!(GL_SPOT_DIRECTION, 3) spotDirection;
		alias get!(GL_SPOT_DIRECTION, 3) spotDirection;

		alias set!(GL_SPOT_EXPONENT, 1) spotExponent;
		alias get!(GL_SPOT_EXPONENT, 1) spotExponent;

		alias set!(GL_SPOT_CUTOFF, 1) spotCutoff;
		alias get!(GL_SPOT_CUTOFF, 1) spotCutoff;

		alias set!(GL_CONSTANT_ATTENUATION, 1) constantAttenuation;
		alias get!(GL_CONSTANT_ATTENUATION, 1) constantAttenuation;

		alias set!(GL_LINEAR_ATTENUATION, 1) linearAttenuation;
		alias get!(GL_LINEAR_ATTENUATION, 1) linearAttenuation;

		alias set!(GL_QUADRATIC_ATTENUATION, 1) quadraticAttenuation;
		alias get!(GL_QUADRATIC_ATTENUATION, 1) quadraticAttenuation;
	}
	public GLLIGHT[] light;

	// VBO
	private struct GLBUFFER(GLenum target) {
		GLenum data_usage;

		GLenum access() {
			GLint i;
			glGetBufferParameteriv(target, GL_BUFFER_ACCESS, &i);
			return cast(GLenum)i;
		}

		bool mapped() {
			GLint i;
			glGetBufferParameteriv(target, GL_BUFFER_MAPPED, &i);
			return i == GL_TRUE;
		}

		uint size() {
			GLint i;
			glGetBufferParameteriv(target, GL_BUFFER_SIZE, &i);
			return cast(uint)i;
		}

		GLenum usage() {
			GLint i;
			glGetBufferParameteriv(target, GL_BUFFER_USAGE, &i);
			return cast(GLenum)i;
		}

		void usage(Frequency frequency, Nature nature) {
			data_usage = GL_STREAM_DRAW;
			switch(frequency) {
			case Frequency.Stream:
				data_usage = nature == Nature.Draw ? GL_STREAM_DRAW :
							 nature == Nature.Read ? GL_STREAM_READ :
							 nature == Nature.Copy ? GL_STREAM_COPY : GL_STREAM_DRAW;
			case Frequency.Static:
				data_usage = nature == Nature.Draw ? GL_STATIC_DRAW :
							 nature == Nature.Read ? GL_STATIC_READ :
							 nature == Nature.Copy ? GL_STATIC_COPY : GL_STATIC_DRAW;
			case Frequency.Dynamic:
				data_usage = nature == Nature.Draw ? GL_DYNAMIC_DRAW :
							 nature == Nature.Read ? GL_DYNAMIC_READ :
							 nature == Nature.Copy ? GL_DYNAMIC_COPY : GL_DYNAMIC_DRAW;
			}
		}

		void[] opSlice() {
			void[] result;
			result.length = size;
			glGetBufferSubData(target, 0, size, result.ptr);
			return result;
		}
		void[] opSlice(uint start, uint end) {
			void[] result;
			result.length = end-start;
			glGetBufferSubData(target, start, end-start, result.ptr);
			return result;
		}

		void opSliceAssign(void[] data) {
			glBufferData(target, data.length, data.ptr, data_usage);
		}
		void opSliceAssign(void[] data, uint start, uint end) {
			glBufferSubData(target, start, end-start, data.ptr);
		}

		void buffer(GLBuffer _buffer) {
			GLint name = 0;
			if(_buffer !is null)
				name = _buffer.id;
			glBindBuffer(target, name);
		}

		bool mapBuffer(GLenum access)(void delegate(void* data) dg) {
			void* data = glMapBuffer(target, access);
			if(data) {
				dg(data);
				glUnmapBuffer(target);
				return true;
			}
			return false;
		}

		alias mapBuffer!(GL_READ_ONLY) read;
		alias mapBuffer!(GL_WRITE_ONLY) write;
		alias mapBuffer!(GL_READ_WRITE) read_write;
	}
	public alias GLBUFFER!(GL_ARRAY_BUFFER) arrayBuffer;
	public alias GLBUFFER!(GL_ELEMENT_ARRAY_BUFFER) elementArrayBuffer;
	public alias GLBUFFER!(GL_PIXEL_PACK_BUFFER) pixelPackBuffer;
	public alias GLBUFFER!(GL_PIXEL_UNPACK_BUFFER) pixelUnpackBuffer;

	// template functions
	private float getFloat(GLuint P)() {
		GLfloat f;
		glGetFloatv(P, &f);
		return cast(float)f;
	}
	private void setBool(GLuint P)(bool enabled) {
		if(enabled)
			glEnable(P);
		else
			glDisable(P);
	}
	private bool getBool(GLuint P)() {
		return cast(bool)glIsEnabled(P);
	}

	// read only OpenGL values
	protected GLfloat[2] m_aliased_point_sizes;

	public void init() {
		GLint i;

		glGetFloatv(GL_ALIASED_POINT_SIZE_RANGE, m_aliased_point_sizes.ptr);

		glGetIntegerv(GL_MAX_TEXTURE_UNITS, &i);
		tu.length = i;
		for(GLenum u = GL_TEXTURE0; i--; u++)
			tu[u - GL_TEXTURE0] = GLTEXTUREUNIT(u);

		glGetIntegerv(GL_MAX_LIGHTS, &i);
		light.length = i;
		for(GLenum u = GL_LIGHT0; i--; u++)
			light[u - GL_LIGHT0] = GLLIGHT(u);
	}

	// scissor
	public alias setBool!(GL_SCISSOR_TEST) scissor;
	public void scissor(int x, int y, int width, int height) {
		glScissor(x, y, width, height);
	}
	public alias getBool!(GL_SCISSOR_TEST) scissor;

	// points
	public float minPointSize() { return m_aliased_point_sizes[0]; }
	public float maxPointSize() { return m_aliased_point_sizes[1]; }

	public void pointSize(float s) { glPointSize(s); }
	public alias getFloat!(GL_POINT_SIZE) pointSize;

	public alias setBool!(GL_POINT_SMOOTH) pointSmooth;
	public alias getBool!(GL_POINT_SMOOTH) pointSmooth;

	public void pointSprite(bool enabled) {
		if(enabled) {
			glEnable(GL_POINT_SPRITE);
			glTexEnvi(GL_POINT_SPRITE, GL_COORD_REPLACE, GL_TRUE);
		} else
			glDisable(GL_POINT_SPRITE);
	}

	// color
	public void color(RGBA rgba) { glColor4ubv(rgba.ptr); }
	public RGBA color() {
		GLint[4] f;
		glGetIntegerv(GL_CURRENT_COLOR, f.ptr);
		return RGBA(f[0], f[1], f[2], f[3]);
	}

	// blending
	public alias setBool!(GL_BLEND) blend;
	public alias getBool!(GL_BLEND) blend;

	public void blendFunc(BlendFunc color)
	in {
		assert(color.dfactor != Blend.src_alpha_saturate);
	} body {
		glBlendFunc(color.sfactor, color.dfactor);
	}
	public BlendFunc blendFunc() {
		GLint s, d;
		glGetIntegerv(GL_BLEND_SRC, &s);
		glGetIntegerv(GL_BLEND_DST, &d);
		return BlendFunc(cast(Blend)s, cast(Blend)d);
	}

	// matrix manipulation
	void inMatrix(void delegate() dg) {
		glPushMatrix();
		dg();
		glPopMatrix();
	}

	void translate(float x, float y, float z = 0.0) {
		glTranslatef(x, y, z);
	}

	void scale(float a) {
		glScalef(a, a, a);
	}

	void scale(float x, float y, float z) {
		glScalef(x, y, z);
	}

	void rotate(float angle, float x, float y, float z) {
		glRotatef(angle, x, y, z);
	}

	// glsl
	void program(GLProgram p) {
		glUseProgram(p ? p.id : 0);
	}

	// framebuffer
	private GLuint m_framebuffer_id = 0;
	void framebuffer(GLFramebuffer fb) {
		GLuint _id = fb ? fb.id : 0;
		if(_id != m_framebuffer_id) {
			glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _id);
			m_framebuffer_id = _id;
		}
	}
}
public GLSTATE glState;

bool continueIfMissing(char[] libName, char[] procName) { return true; }
static this() {
	Derelict_SetMissingProcCallback(&continueIfMissing);
	DerelictSDLImage.load();
	glState = new GLSTATE();
}

static ~this() {
	DerelictSDLImage.unload();
}

