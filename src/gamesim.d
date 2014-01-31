module gamesim;

import tango.math.Math;
import tango.time.Clock : Clock;

import simulation : Simulation, Ent;
import network : Buffer;
import glutil : BlendFunc, Blend, Wrap, Image2D, RGBA, GLProgram, GLTexture2D, glState;
import util : itoa, MatrixFixed, Vec2D, GameRand, Queue, open_text, Vec3D;
import engine : MMHI;

GameRand random;

version = client;

class GameSimulation : Simulation {
	override Ent spawn(uint type, Buffer* buf) {
		switch(type) {
		case EntType.map:
			return new Map(buf);
		case EntType.debris:
			return new Debris(buf);
		case EntType.structure:
			return new Structure(buf);
		case EntType.base:
			return new Base(buf);
		case EntType.bot:
			return new Bot(buf);
		case EntType.bolt:
			return new Bolt(buf);
		default:
			throw new Exception("unexpected type: " ~ itoa(type));
		}
	}
}

enum EntType : uint {
	none,
	map,
	debris,
	structure,
	base,
	bot,
	bolt
}

enum Team {
	world,
	blue,
	red
}

class Entity : Ent {
	Vec2D location() { return m_location; }
	Vec2D velocity() { return m_velocity; }
	float radius() { return m_radius; }
	float rotation() { return m_rotation; }
	Team team() { return m_team; }

	void think(uint delay, int function(Entity* e) func) {
		m_think_time = simulation.time + delay;
		m_think_func = func;
	}
	void think() {
		if(m_think_time && simulation.time >= m_think_time) {
			int r = m_think_func(&this);
			m_think_time = r ? simulation.time + r : 0;
		}
	}

private:
	Vec2D m_location = {0, 0};
	Vec2D m_velocity = {0, 0};
	float m_radius = 1.0;
	float m_rotation = 0.0;
	Team m_team;

	uint m_think_time;
	int function(Entity* e) m_think_func;
}

class Map : Entity {
	uint type() { return EntType.map; }

	static const uint map_size = 64+1;

	this(Buffer* data) {
		read(data, true);
	}

	this() {
		m_team = Team.world;

		MatrixFixed!(float, map_size, map_size) data;

		random.seed(Clock.now.ticks);

		data[           0,            0] = 127.0 + random.dfrac() * 64.0;
		data[           0, map_size - 1] = 127.0 + random.dfrac() * 64.0;
		data[map_size - 1, map_size - 1] = 127.0 + random.dfrac() * 64.0;
		data[map_size - 1,            0] = 127.0 + random.dfrac() * 64.0;

		struct WorkUnit {
			int minx;
			int maxx;
			int miny;
			int maxy;
			float scale;
		}
		WorkUnit wu;
		auto queue = new Queue!(WorkUnit, 2048);
		queue.push(WorkUnit(0, map_size - 1, 0, map_size - 1, 127.0));

		while(queue.pop(wu)) {
			if(wu.maxx - wu.minx <= 1 || wu.maxy - wu.miny <= 1) continue;

			int midx = (wu.minx + wu.maxx) / 2;
			int midy = (wu.miny + wu.maxy) / 2;

			// get the four corners
			float ii = data[wu.minx, wu.miny];
			float ia = data[wu.minx, wu.maxy];
			float aa = data[wu.maxx, wu.maxy];
			float ai = data[wu.maxx, wu.miny];

			// set the middle
			data[   midx,	midy] = ((ii + ia + aa + ai) / 4) + random.dfrac() * wu.scale;

			// set the midpoint of the sides
			data[wu.minx,	midy] = ((ii + ia) / 2) - random.dfrac() * wu.scale;
			data[   midx, wu.maxy] = ((ia + aa) / 2) - random.dfrac() * wu.scale;
			data[wu.maxx,	midy] = ((aa + ai) / 2) - random.dfrac() * wu.scale;
			data[   midx, wu.miny] = ((ai + ii) / 2) - random.dfrac() * wu.scale;

			// descend into four smaller squares
			queue.push(WorkUnit(wu.minx,	midx, wu.miny,	midy, wu.scale * 0.5));
			queue.push(WorkUnit(   midx, wu.maxx, wu.miny,	midy, wu.scale * 0.5));
			queue.push(WorkUnit(wu.minx,	midx,	midy, wu.maxy, wu.scale * 0.5));
			queue.push(WorkUnit(   midx, wu.maxx,	midy, wu.maxy, wu.scale * 0.5));
		}

		for(uint x = 0; x < map_size; x++) {
			for(uint y = 0; y < map_size; y++) {
				float p = data[x, y];
				if(p < 0.0) p = 0.0;
				if(p > 255.0) p = 255.0;
				m_data[x, y] = cast(ubyte)p;
			}
		}
	}

	version(client) {
		void render(MMHI engine) {
			glState.program = m_program;
			glState.tu[0].texture = m_sky;
			glState.tu[1].texture = m_diffuse;
			glState.tu[2].texture = m_norm;

			m_program.uniform("camera", engine.camera.x, engine.camera.y);
			m_program.uniform("skymap", 0);
			m_program.uniform("colormap", 1);
			m_program.uniform("normmap", 2);
			
			glState.blendFunc = BlendFunc(Blend.one, Blend.one);
			glState.blend = true;

			engine.lights((Vec3D xyz, Vec3D rgb, float radius) {
				m_program.uniform("LightPos", xyz.x, xyz.y, xyz.z);
				m_program.uniform("LightColor", rgb.x, rgb.y, rgb.z, radius);
				engine.quad(-1024, -1024, 1024, 1024);
			});
			
			glState.blend = false;

			glState.tu[2].texture = null;
			glState.tu[1].texture = null;
			glState.tu[0].texture = null;
		}

		void effects(MMHI engine) {
			engine.addLight(0.0, 0.0, 512.0f, 0.6, 0.6, 0.5, 2048.0);
		}
	}

	void read(Buffer* data, bool spawn = false) {
		uint x, y;
		for(x = 0; x < map_size; x++)
			for(y = 0; y < map_size; y++)
				m_data[x, y] = data.r!(ubyte);

		version(client) {
			MatrixFixed!(float, map_size, map_size) f_data;
			for(x = 0; x < map_size; x++)
				for(y = 0; y < map_size; y++)
					f_data[x, y] = m_data[x, y] * (1.0f / 255.0f);

			Image2D img = new Image2D(map_size, map_size);
			for(x = 0; x < map_size; x++) {
				uint x0 = x > 0 ? x - 1 : x;
				uint x1 = x;
				uint x2 = (x == map_size - 1 ? x : x + 1);
				for(y = 0; y < map_size; y++) {
					uint y0 = y > 0 ? y - 1 : y;
					uint y1 = y;
					uint y2 = (y == map_size - 1 ? y : y + 1);
					/*
					Coordinates are laid out as follows:
						0,0 | 1,0 | 2,0
						----+-----+----
						0,1 | 1,1 | 2,1
						----+-----+----
						0,2 | 1,2 | 2,2
					*/

					// Use of the sobel filter requires the eight samples
					// surrounding the current pixel:
					float h00 = f_data[x0, y0];
					float h10 = f_data[x1, y0];
					float h20 = f_data[x2, y0];

					float h01 = f_data[x0, y1];
					float h21 = f_data[x2, y1];

					float h02 = f_data[x0, y2];
					float h12 = f_data[x1, y2];
					float h22 = f_data[x2, y2];

					// The Sobel X kernel is:
					// [ 1.0  0.0  -1.0 ]
					// [ 2.0  0.0  -2.0 ]
					// [ 1.0  0.0  -1.0 ]
					float Gx = h00 - h20 + 2.0f * h01 - 2.0f * h21 + h02 - h22;

					// The Sobel Y kernel is:
					// [  1.0    2.0    1.0 ]
					// [  0.0    0.0    0.0 ]
					// [ -1.0   -2.0   -1.0 ]
					float Gy = h00 + 2.0f * h10 + h20 - h02 - 2.0f * h12 - h22;

					// Generate the missing Z component - tangent
					// space normals are +Z which makes things easier
					// The 0.5f leading coefficient can be used to control
					// how pronounced the bumps are - less than 1.0 enhances
					// and greater than 1.0 smoothes.
					float Gz = 0.7f * sqrt(1.0f - Gx * Gx - Gy * Gy);

					Vec3D v = Vec3D(2.0f * Gx, 2.0f * Gy, Gz).normalized * 0.5 + 0.5;

					img[x, y] = RGBA(cast(ubyte)(v.x * 255), cast(ubyte)(v.y * 255), cast(ubyte)(v.z * 255), m_data[x, y]);
				}
			}

			m_program = new GLProgram();
			m_program.vertex(open_text("scripts/terrain.vert"));
			m_program.fragment(open_text("scripts/terrain.frag"));
			m_program.link();

			m_sky = glState.texture2D("images/clouds.tga");

			m_diffuse = new GLTexture2D();
			m_diffuse.wrapS = Wrap.mirrored_repeat;
			m_diffuse.wrapT = Wrap.mirrored_repeat;
			m_diffuse.generateMipmap = true;
			m_diffuse.image = img;

			m_norm = glState.texture2D("images/terraintex/ground2_norm.tga");
		}
	}

	void write(Buffer* data, bool spawn = false) {
		for(uint x = 0; x < map_size; x++)
			for(uint y = 0; y < map_size; y++)
				data.w!(ubyte) = m_data[x, y];
	}

	MatrixFixed!(ubyte, map_size, map_size) data() {
		return m_data;
	}

	bool inWater(float x, float y) {
		return getHeight(x, y) < 64;
	}

	ubyte getHeight(float _x, float _y) {
		Vec2D xy = Vec2D(_x, _y) * (1.0f / 2048.0f) + 0.5f * map_size;
		return m_data[(cast(uint)xy.x), (cast(uint)xy.y)];
	}

private:
	MatrixFixed!(ubyte, map_size, map_size) m_data;

	version(client) {
		GLProgram m_program;
		GLTexture2D m_diffuse;
		GLTexture2D m_norm;
		GLTexture2D m_sky;
	}
}

GLProgram sprite_program;
bool sprite_program_loaded = false;

class Debris : Entity {
	uint type() { return EntType.debris; }

	this(Buffer* data) {
		read(data, true);
	}

	this(float x, float y) {
		m_location.x = x;
		m_location.y = y;
	}

	version(client) {
		void render(MMHI engine) {
		}
	}

	void read(Buffer* data, bool spawn = false) {
		m_location.x = data.r!(float);
		m_location.y = data.r!(float);
	}

	void write(Buffer* data, bool spawn = false) {
		data.w!(float) = m_location.x;
		data.w!(float) = m_location.y;
	}
}

class Structure : Entity {
	uint type() { return EntType.structure; }

	this(Buffer* data) {
		read(data, true);
	}

	this(float x, float y) {
		m_location.x = x;
		m_location.y = y;
	}

	version(client) {
		void render(MMHI engine) {
			glState.program = null;
			glState.blendFunc = BlendFunc(Blend.src_alpha, Blend.one_minus_src_alpha);
			glState.blend = true;
			glState.color = RGBA(127, 127, 127, 255);
			glState.tu[0].texture = glState.texture2D("images/debris01.tga");
			engine.quad(m_location.x - 32, m_location.y - 32, m_location.x + 32, m_location.y + 32);
		}

		void effects(MMHI engine) {
			engine.addLight(location.x, location.y, 50.0f, 0.2, 0.2, 0.2, 256.0);
		}
	}

	void read(Buffer* data, bool spawn = false) {
		m_location.x = data.r!(float);
		m_location.y = data.r!(float);
	}

	void write(Buffer* data, bool spawn = false) {
		data.w!(float) = m_location.x;
		data.w!(float) = m_location.y;
	}
}

class Base : Entity {
	uint type() { return EntType.base; }

	this(Buffer* data) {
		read(data, true);
	}

	this(float x, float y, Team _team) {
		m_location.x = x;
		m_location.y = y;
		m_team = _team;
	}

	void init() {
		think(10, function int(Entity* e) {
			Vec2D location = e.location;
			e.simulation.attach(new Bot(location.x, location.y, e.m_team));
			return 10000;
		});
	}

	version(client) {
		void render(MMHI engine) {
			glState.color = m_team == Team.blue ? RGBA(0, 0, 255, 255) : RGBA(255, 0, 0, 255);
			engine.quad(location.x - 32, location.y - 32, location.x + 32, location.y + 32);
		}

		void effects(MMHI engine) {
			if(m_team == Team.blue)
				engine.addLight(location.x, location.y, 50.0f, 0.1, 0.1, 0.5, 256.0);
			else
				engine.addLight(location.x, location.y, 50.0f, 0.5, 0.1, 0.1, 256.0);
		}
	}

	void read(Buffer* data, bool spawn = false) {
		m_location.x = data.r!(float);
		m_location.y = data.r!(float);
		if(spawn)
			m_team = cast(Team)data.r!(ubyte);
	}

	void write(Buffer* data, bool spawn = false) {
		data.w!(float) = m_location.x;
		data.w!(float) = m_location.y;
		if(spawn)
			data.w!(ubyte) = cast(ubyte)m_team;
	}
}

class Bot : Entity {
	uint type() { return EntType.bot; }

	this(Buffer* data) {
		read(data, true);
	}

	this(float x, float y, Team _team) {
		m_location.x = x;
		m_location.y = y;
		m_team = _team;
	}

	void init() {
		think(1, function int(Entity* e) {
			e.m_location = e.m_location + Vec2D(random.dfrac() * 2, random.dfrac() * 2);
			e.modified;
			return 1;
		});
	}

	version(client) {
		void render(MMHI engine) {
			if(!sprite_program_loaded) {
				sprite_program_loaded = true;
				sprite_program = new GLProgram();
				sprite_program.vertex(open_text("scripts/sprite.vert"));
				sprite_program.fragment(open_text("scripts/sprite.frag"));
				sprite_program.link();
			}

			glState.color = m_team == Team.blue ? RGBA(0, 0, 255, 255) : RGBA(255, 0, 0, 255);

			glState.program = sprite_program;
			glState.tu[0].texture = glState.texture2D("images/bot1_color.tga");
			glState.tu[1].texture = glState.texture2D("images/bot1_bump.tga");

			sprite_program.uniform("colormap", 0);
			sprite_program.uniform("normmap", 1);
			sprite_program.uniform("time", simulation.time * 0.001);

			glState.inMatrix({
				glState.translate(location.x, location.y);
				glState.rotate(number * (simulation.time * 0.001), 0, 0, 1);
				engine.quad(-4, -4, 4, 4);
			});

			glState.tu[1].texture = null;
			glState.tu[0].texture = null;
		}
	}

	void read(Buffer* data, bool spawn = false) {
		m_location.x = data.r!(float);
		m_location.y = data.r!(float);
		if(spawn)
			m_team = cast(Team)data.r!(ubyte);
	}

	void write(Buffer* data, bool spawn = false) {
		data.w!(float) = m_location.x;
		data.w!(float) = m_location.y;
		if(spawn)
			data.w!(ubyte) = cast(ubyte)m_team;
	}
}

class Bolt : Entity {
	uint type() { return EntType.bolt; }

	this(Buffer* data) {
		read(data, true);
	}

	this(float x, float y, float z, float w, Entity _owner) {
		m_location.x = x;
		m_location.y = y;
		m_velocity.x = z;
		m_velocity.y = w;
		m_owner = _owner;
	}

	version(client) {
		void render(MMHI engine) {
			glState.program = null;
			glState.color = RGBA(255, 255, 0, 255);

			Vec2D loc = Vec2D(
				location.x + velocity.x * (simulation.time - m_start_time) * 0.1f,
				location.y + velocity.y * (simulation.time - m_start_time) * 0.1f
			);
			engine.point(1.0, loc.x, loc.y);
		}
	}

	void read(Buffer* data, bool spawn = false) {
		m_location.x = data.r!(float);
		m_location.y = data.r!(float);
		m_velocity.x = data.r!(float);
		m_velocity.y = data.r!(float);
	}

	void write(Buffer* data, bool spawn = false) {
		data.w!(float) = m_location.x;
		data.w!(float) = m_location.y;
		data.w!(float) = m_velocity.x;
		data.w!(float) = m_velocity.y;
	}

private:
	Entity m_owner;
	uint m_start_time;
}

