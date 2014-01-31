module simulation;

import tango.io.Stdout;
private import tango.core.Signal : Signal;

import network : Connection, Buffer;

version(client)
	import engine : MMHI;

enum EntPacket : ubyte {
	remove,
	modify,
	spawn
}

class Simulation {
	this() {
		m_network_buffer = Buffer(0x7fff);
	}

	~this() {
	}

	void send(ref Connection con) {
		Buffer packet = ~m_network_buffer;

		uint spawned, modified, removed;
		each((inout Ent e) {
			if(e.spawned(con.out_revision)) {
				packet.w!(ushort) = e.number;
				packet.w!(ubyte) = EntPacket.spawn | (cast(ubyte)e.type << 2);
				e.write(&packet, true);
				spawned++;
			} else if(e.modified(con.out_revision)) {
				packet.w!(ushort) = e.number;
				packet.w!(ubyte) = EntPacket.modify;
				e.write(&packet);
				modified++;
			}
		});
		foreach(n, r; m_removed_ents) {
			if(r > con.out_revision) {
				packet.w!(ushort) = n;
				packet.w!(ubyte) = EntPacket.remove;
				removed++;
			}
		}

		if(spawned || modified || removed) {
			if(m_revised)
				m_revision++;
			m_revised = false;

			con.send(packet, m_revision);
		}
	}

	void receive(ref Connection con) {
		Buffer buf = con.receive();
		while(buf.avail) {
			ushort i = buf.r!(ushort);
			ubyte t = buf.r!(ubyte);
			switch(t & 0x03) {
			case EntPacket.remove:
				m_ents.remove(i);
				break;
			case EntPacket.modify:
				m_ents[i].read(&buf);
				break;
			case EntPacket.spawn:
				uint type = cast(uint)(t >> 2);
				this.attach(spawn(type, &buf), i);
				break;
			}
		}
	}

	void advance(uint elapsed) {
		m_total_time_collected += elapsed;
		m_time_collected += elapsed;
		while(m_time_collected > 100) {
			m_time_collected -= 100;
			m_time++;
			
			each((inout Ent e) {
				e.think();
			});
		}
	}

	version(client) {
		void render(MMHI engine) {
			each((inout Ent e) {
				e.render(engine);
			});
		}

		void effects(MMHI engine) {
			each((inout Ent e) {
				e.effects(engine);
			});
		}
	}

	void each(void delegate(inout Ent e) dg) {
		foreach(i, e; m_ents)
			dg(e);
	}

	uint time() {
		return m_total_time_collected;
	}

	ushort gen() {
		for(uint i = 0; i < 0x7fff; i++) {
			if(i in m_ents) continue;
			return i;
		}
		return 0;
	}
	void remove(Ent e) {
		assert(e.number in m_ents);
		m_ents.remove(e.number);
		m_removed_ents[e.number] = m_revision;
	}

	uint revision() {
		return m_revision;
	}
	void revised() {
		m_revised = true;
	}

	// as client
	void attach(Ent e, uint number) {
		e.attach(this, number);
		if(e.number in m_removed_ents) m_removed_ents.remove(e.number);
		m_ents[e.number] = e;
	}

	// as server
	void attach(Ent e) {
		e.attach(this, gen());
		if(e.number in m_removed_ents) m_removed_ents.remove(e.number);
		m_ents[e.number] = e;

		e.m_spawn_revision = revision + 1;
		revised;

		e.init;
	}

	abstract Ent spawn(uint type, Buffer* buf);

    void onAdvance(void delegate(Ent* e) dg) { m_onAdvance.attach(dg); }

private:
	uint[ushort] m_removed_ents;
	Ent[ushort] m_ents;
	Buffer m_network_buffer;

    Signal!(Ent*) m_onAdvance;

	bool m_revised;
	uint m_revision;

	bool m_editing;

	uint m_total_time_collected;
	uint m_time_collected;
	uint m_time;
}

class Ent {
	uint type() { return 0; }
	Simulation simulation() { return m_simulation; }
	uint number() { return m_number; }

	final void attach(Simulation _simulation, uint _number) {
		m_simulation = _simulation;
		m_number = _number;
	}

	void remove() {
		m_simulation.remove(this);
	}

	void init() { }
	void think() { }
	version(client) {
		void render(MMHI engine) { }
		void effects(MMHI engine) { }
	}
	void read(Buffer* data, bool spawn = false) { }
	void write(Buffer* data, bool spawn = false) { }

	bool spawned(uint revision) { return m_spawn_revision > revision; }
	void modified() {
		m_modify_revision = simulation.revision + 1;
		m_simulation.revised;
	}
	bool modified(uint revision) { return m_modify_revision > revision; }

private:
	Simulation m_simulation;
	uint m_number;

	uint m_spawn_revision = 0;
	uint m_modify_revision = 0;
}

