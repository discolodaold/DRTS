module main;

import tango.io.Stdout;
import tango.math.Math;
import tango.core.Thread : Fiber;

import network : Buffer, Connection;
import gamesim : GameSimulation, Map, Structure, Base, Team;
import engine : MMHI;

import util : GameRand, Vec2D;

GameRand random;

void playGame() {
	auto simulation = new GameSimulation();
	
	Connection connection;

	// for now, make a connection to a server we make our own
	uint elapsed_server_time;
	auto server = new Fiber({
		auto sim = new GameSimulation();
		Connection con;

		con.loopback_connection = &connection;
		connection.loopback_connection = &con;

		Map m = new Map;

		sim.attach(m);

		uint i = 64 + (random() % 64);
		while(i--) {
			float x;
			float y;
			do {
				x = random.dfrac() * 1024;
				y = random.dfrac() * 1024;
			} while(m.inWater(x, y));
			sim.attach(new Structure(x, y));
		}

		i = 4;
		while(i--) {
			float x;
			float y;
			do {
				x = random.frac() * -1024;
				y = random.dfrac() * 1024;
			} while(m.inWater(x, y));
			sim.attach(new Base(x, y, Team.blue));
		}

		i = 4;
		while(i--) {
			float x;
			float y;
			do {
				x = random.frac() * 1024;
				y = random.dfrac() * 1024;
			} while(m.inWater(x, y));
			sim.attach(new Base(x, y, Team.red));
		}

		while(true) {
			Fiber.yield();

			sim.receive(con);
			sim.advance(elapsed_server_time);
			sim.send(con);
		}
	});
	server.call();

	float zoom_target = 1.0;
	auto engine = new MMHI;
	with(engine) {
		createGLWindow("game", 800, 600);

		onRender({
			if(zoom_target > 10) zoom_target = 10;
			if(zoom_target < 0.1) zoom_target = 0.1;
			zoom = zoom + (zoom_target - zoom) * 0.1;

			simulation.effects(engine);
			simulation.render(engine);
		});

		onAdvance((uint elapsed) {
			elapsed_server_time = elapsed;
			server.call();

			simulation.receive(connection);
			simulation.advance(elapsed);
			simulation.send(connection);
		});

		onMouseMotion((ubyte state, ushort x, ushort y, short xrel, short yrel) {
			Vec2D rel = Vec2D(-xrel, -yrel) * (1.0 / zoom);
			if(state & 4)
				camera = camera + rel;
		});

		onMouseWheelUp(() {
			zoom_target += 0.1 * zoom;
		});

		onMouseWheelDown(() {
			zoom_target -= 0.1 * zoom;
		});

		onKeyPressed((int key) {
		});

		onKeyReleased((int key) {
		});

		run;
	}
}

int main(char[][] arguments) {
	playGame();
	return 0;
}

