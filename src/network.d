module network;

import util : Queue, itoa;

struct Buffer {
    byte[] _buffer;
    byte[] _data;

    static Buffer opCall(uint size) {
        Buffer buf;
        buf._buffer.length = size;
        return ~buf;
    }
    static Buffer opCall(byte[] data) {
        Buffer buf;
        buf._buffer.length = data.length;
		buf._buffer[0 .. $] = data[0 .. $];
        return ~buf;
    }

    Buffer opCom() {
        _data = _buffer;
        return *this;
    }

    uint length() {
        return _buffer.length - _data.length;
    }

    uint avail() {
        return _data.length;
    }

    T r(T)()
    in {
        assert(_data.length >= T.sizeof);
    } body {
        T r = *(cast(T*)_data.ptr);
        _data = _data[T.sizeof .. $];
        return r;
    }

    void w(T)(T r)
    in {
        assert(_data.length >= T.sizeof, "network write overflow");
    } body {
        *(cast(T*)_data.ptr) = r;
        _data = _data[T.sizeof .. $];
    }

    byte[] opSlice() {
        return _buffer.ptr[0 .. _data.ptr - _buffer.ptr];
    }

	char[] toString() {
		return "<buffer " ~ itoa(length) ~ " " ~ itoa(avail) ~ ">";
	}
}

struct Connection {
	Connection* loopback_connection;
    Queue!(byte[], 32) loop;
    uint in_revision;
    uint out_revision;

    void send(Buffer buf, uint revision, bool ack = false) {
        Buffer header = Buffer(ushort.sizeof + uint.sizeof);
        header.w!(ushort) = ack ? 0x8006 : buf.length + 6;
        header.w!(uint) = revision;

        byte[] data = header[] ~ buf[];

		if(loopback_connection)
			loopback_connection.loop.push(data);
    }

    Buffer receive() {
        uint revision;
        ushort code;

        byte[] data;

        while(1) {
			if(loopback_connection) {
				if(!loop.pop(data))
					return Buffer(0);
			}

            Buffer buf = Buffer(data);
            code = buf.r!(ushort);
            revision = buf.r!(uint);

            if(code & 0x8000) {
				version(network_trace)
					Stdout.formatln("<- ack {}", revision);
				if(revision > out_revision)
	                out_revision = revision;
                continue;
            }

            if(data.length != code & ~0x8000)
                throw new Exception("package length does not match from header " ~ itoa(data.length) ~ " vrs " ~ itoa(code & ~ 0x8000));

            if(in_revision >= revision)
                continue;
            in_revision = revision;

            send(Buffer(0), revision, true);

            return buf;
        }
    }
}

