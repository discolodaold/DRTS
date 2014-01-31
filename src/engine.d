module engine;

private import derelict.sdl.sdl;
private import derelict.opengl.gl;
private import derelict.opengl.extension.ext.framebuffer_object;
private import                 extension.ext.direct_state_access;
private import derelict.opengl.glu;
private import tango.stdc.stringz;
private import tango.io.Stdout;
private import tango.core.Signal : Signal;

private import simulation : Ent;
private import util : Vec2D, itoa, MemoryPool, Vec3D;
private import glutil : GLTexture2D, glState, glError, GLProgram, GLFramebuffer, BlendFunc, Blend;
private import models;

public class MMHI {
    this() {
        DerelictSDL.load();
        DerelictGL.load();
        DerelictGLU.load();

        if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER) < 0)
            throw new Exception("Failed to initialize SDL");

        if((SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL)))
            throw new Exception("Failed to set key repeat");

        m_camera = Vec2D(0.0, 0.0);
        m_zoom = 1.0;

		m_lights_avail.length = 32;
    }

    ~this() {
        SDL_Quit();

        DerelictSDL.unload();
        DerelictGL.unload();
        DerelictGLU.unload();
    }

    void createGLWindow(char[] title, int width, int height, int bits = 32, bool fullScreen = false) {
        SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
        SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 6);
        SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
        SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

        SDL_WM_SetCaption(toStringz(title), null);

        int mode = SDL_OPENGL;
        if(fullScreen)
            mode |= SDL_FULLSCREEN;

        if(SDL_SetVideoMode(width, height, bits, mode) is null)
            throw new Exception("Failed to open OpenGL window");

        assert(DerelictGL.availableVersion() >= GLVersion.Version21);
		DerelictGL.loadExtensions();

		m_framebuffer = new GLFramebuffer();
		m_diffuse_texture = new GLTexture2D();
		m_normal_texture = new GLTexture2D();
		m_glow_texture = new GLTexture2D();

        resizeGLScene(width, height);

		m_framebuffer.color0 = m_diffuse_texture;
		m_framebuffer.color1 = m_normal_texture;
		m_framebuffer.color2 = m_glow_texture;
        
		glState.init();
    }

    void onAdvance(void delegate(uint elapsed) dg) { m_onAdvance.attach(dg); }
    void onRender(void delegate() dg) { m_onRender.attach(dg); }
    void onMouseMotion(void delegate(ubyte state, ushort x, ushort y, short xrel, short yrel) dg) { m_onMouseMotion.attach(dg); }
    void onMouseWheelUp(void delegate() dg) { m_onMouseWheelUp.attach(dg); }
    void onMouseWheelDown(void delegate() dg) { m_onMouseWheelDown.attach(dg); }
    void onKeyReleased(void delegate(int key) dg) { m_onKeyReleased.attach(dg); }
    void onKeyPressed(void delegate(int key) dg) { m_onKeyPressed.attach(dg); }

    Vec2D camera() { return m_camera; }
    void camera(Vec2D _camera) { m_camera = _camera; }
    float zoom() { return m_zoom; }
    void zoom(float _zoom) { return m_zoom = _zoom; }
	uint width() { return m_width; }
	uint height() { return m_height; }

    void run() {
        m_running = true;
        while(m_running) {
            processEvents();

            m_onAdvance(SDL_GetTicks() - m_lastTick);
            m_lastTick = SDL_GetTicks();

            glClear(GL_COLOR_BUFFER_BIT);

			glState.inMatrix({
				glState.translate(m_width / 2, m_height / 2);
				glState.scale(zoom);
				glState.translate(-camera.x, -camera.y);

				m_lights = m_lights_avail;

				glState.framebuffer = m_framebuffer;

				m_onRender();

				glState.framebuffer = null;

			});

			glState.program = m_deffered_lighting;
		
			glState.blendFunc = BlendFunc(Blend.one, Blend.one);
			glState.blend = true;

			lights((Vec3D xyz, Vec3D rgb, float radius) {
			try {
				m_deffered_lighting.uniform("LightPos", xyz.x, xyz.y, xyz.z);
				m_deffered_lighting.uniform("LightColor", rgb.x, rgb.y, rgb.z, radius);
			} catch(Exception e) {
				throw new Exception("bob");
			}
				m_deffered_lighting.quad(-1024, -1024, 1024, 1024);
			});

			glState.blend = false;
			glState.program = null;

            SDL_GL_SwapBuffers();
            SDL_Delay(10);
        }
    }

	void addLight(float x, float y, float z, float r, float g, float b, float radius) {
		addLight(Vec3D(x, y, z), Vec3D(r, g, b), radius);
	}
	void addLight(Vec3D xyz, float r, float g, float b, float radius) {
		addLight(xyz, Vec3D(r, g, b), radius);
	}
	void addLight(float x, float y, float z, Vec3D rgb, float radius) {
		addLight(Vec3D(x, y, z), rgb, radius);
	}
	void addLight(Vec3D xyz, Vec3D rgb, float radius) {
		if(m_lights.length == 0) {
			m_lights_avail.length = m_lights_avail.length + 32;
			m_lights = m_lights.ptr[0 .. 32];
		}
		m_lights[0].xyz = xyz;
		m_lights[0].rgb = rgb;
		m_lights[0].radius = radius;
		m_lights = m_lights[1 .. $];
	}

	void lights(void delegate(Vec3D xyz, Vec3D rgb, float radius) dg) {
		glState.scissor = true;
		for(light* l = m_lights_avail.ptr; l < m_lights.ptr; l++) {
			// project light to scissor box
			Vec2D min = Vec2D(l.xyz.x, -l.xyz.y) - l.radius;
			Vec2D max = Vec2D(l.xyz.x, -l.xyz.y) + l.radius;
			min = unproject(min);
			max = unproject(max) - min;
			glState.scissor(cast(int)min.x, cast(int)min.y, cast(int)max.x, cast(int)max.y);

			dg(l.xyz, l.rgb, l.radius);
		}
		glState.scissor = false;
	}

	Vec2D project(Vec2D xy) {
		return (xy - Vec2D(m_width / 2, m_height / 2)) / zoom + camera;
	}

	Vec2D unproject(Vec2D xy) {
		return Vec2D(
			(xy.x - camera.x)*zoom + m_width/2,
			(xy.y + camera.y)*zoom + m_height/2
		);
	}

private:
    void resizeGLScene(GLsizei width, GLsizei height) {
        if(height == 0)
            height = 1;

        glViewport(0, 0, width, height);

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, width, height, 0, 0, 1);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

		m_width = width;
		m_height = height;

		m_diffuse_texture.resize(m_width, m_height);
		m_normal_texture.resize(m_width, m_height);
		m_glow_texture.resize(m_width, m_height);
    }

    void processEvents() {
        SDL_Event event;
        while(SDL_PollEvent(&event)) {
            switch(event.type) {
                case SDL_KEYUP:
                    m_onKeyReleased(event.key.keysym.sym);
                    break;
                case SDL_KEYDOWN:
                    m_onKeyPressed(event.key.keysym.sym);
                    break;
                case SDL_MOUSEMOTION:
                    m_onMouseMotion(event.motion.state, event.motion.x, event.motion.y, event.motion.xrel, event.motion.yrel);
                    break;
                case SDL_MOUSEBUTTONDOWN:
                    if(event.button.button == SDL_BUTTON_WHEELUP)
                        m_onMouseWheelUp();
                    if(event.button.button == SDL_BUTTON_WHEELDOWN)
                        m_onMouseWheelDown();
                    break;
                case SDL_QUIT:
                    m_running = false;
                    break;
                default:
                    break;
            }
        }
    }

    Signal!(uint) m_onAdvance;
    Signal!() m_onRender;
    Signal!(ubyte, ushort, ushort, short, short) m_onMouseMotion;
    Signal!() m_onMouseWheelUp;
    Signal!() m_onMouseWheelDown;
    Signal!(int) m_onKeyReleased;
    Signal!(int) m_onKeyPressed;

    Vec2D m_camera;
    float m_zoom;
	
	struct light {
		Vec3D xyz;
		Vec3D rgb;
		float radius;
	}
	light[] m_lights_avail;
	light[] m_lights;

    bool m_running;
    uint m_lastTick;
	uint m_width;
	uint m_height;

	GLProgram m_deffered_lighting;
	GLFramebuffer m_framebuffer;
	GLTexture2D m_diffuse_texture;
	GLTexture2D m_normal_texture;
	GLTexture2D m_glow_texture;
}

