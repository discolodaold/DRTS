module util;

private {
    import tango.text.Text;
    import tango.core.Exception;
    import tango.math.Math;
    import tango.io.File;
}

template meta_decimaldigit(int n) { const char [] meta_decimaldigit = "0123456789"[n..n+1]; }

template meta_itoa(long n) {
	static if(n < 0)
		const char [] meta_itoa = "-" ~ meta_itoa!(-n);
	else static if(n < 10L)
		const char [] meta_itoa = meta_decimaldigit!(n);
	else
		const char [] meta_itoa = meta_itoa!(n / 10L) ~ meta_decimaldigit!(n % 10L);
}

char[] itoa(long n) {
    char[] t = new char[](16);
    char* p = t.ptr + t.length;
    do {
        *--p = (n % 10) + '0';
    } while(n /= 10);
    return t[p-t.ptr .. $];
}

struct MatrixFixed(T, uint ROW, uint COL) {
    T [ROW * COL] _data;

    T opIndex(uint r, uint c)
    in {
        assert(r >= 0 && r < ROW, "opIndex: row index expression \"0 < " ~ itoa(r) ~ " < " ~ meta_itoa!(ROW) ~ "\" not true");
        assert(c >= 0 && c < COL, "opIndex: column index expression \"0 < " ~ itoa(c) ~ " < " ~ meta_itoa!(COL) ~ "\" not true");
    } body {
        return _data[c * ROW + r];
    }

    T opIndexAssign(T value, uint r, uint c)
    in {
        assert(r >= 0 && r < ROW, "opIndexAssign: row index expression \"0 < " ~ itoa(r) ~ " < " ~ meta_itoa!(ROW) ~ "\" not true");
        assert(c >= 0 && c < COL, "opIndexAssign: column index expression \"0 < " ~ itoa(c) ~ " < " ~ meta_itoa!(COL) ~ "\" not true");
    } body {
        _data[c * ROW + r] = value;
        return value;
    }
}

alias MatrixFixed!(real, 2, 2) Matrix2x2;

struct VectorFixed(T, uint SIZE) {
    T [SIZE] _data;

    T opIndex(uint i)
    in {
        assert(i > -SIZE, "opIndex: vector index below bounds");
        assert(i < SIZE, "opIndex: vector index above bounds");
    } body {
        return _data[i];
    }

    T opIndexAssign(T value, uint i)
    in {
        assert(i >= 0, "opIndexAssign: vector index below bounds");
        assert(i < SIZE, "opIndexAssign: vector index above bounds");
    } body {
        _data[i] = value;
        return value;
    }
}

private class MemoryPool(T, uint PAGE_SIZE) {
    this() {
        m_pageStart = new MemoryPage;
        m_pageCurrent = m_pageStart;
        m_items = m_pageCurrent.pool;
    }

    T* opCall() {
        if(m_items.length == 0) {
            if(m_pageCurrent.next is null)
                m_pageCurrent = new MemoryPage;
            m_pageCurrent = m_pageCurrent.next;
			m_items = m_pageCurrent.pool[];
        }
        T* result = m_items.ptr;
        m_items = m_items[1 .. $];
        return result;
    }

    int opApply(int delegate(ref T) dg) {
        int result = 0;

        auto page = m_pageStart;
        for(; page != m_pageCurrent; page = page.next) {
            for(uint i = 0; i < PAGE_SIZE; ++i) {
                result = dg(page.pool[i]);
                if(result)
                    return result;
            }
        }

        foreach(render; page.pool) {
            result = dg(render);
            if(result) break;
        }

        return result;
    }

    void clear() {
        m_pageCurrent = m_pageStart;
        m_items = m_pageCurrent.pool[];
    }

private:
    struct MemoryPage {
        T[PAGE_SIZE] pool;
        MemoryPage* next;
    }

    MemoryPage* m_pageStart;
    MemoryPage* m_pageCurrent;
    T[] m_items;
}

struct Queue(T, uint MAX) {
    T[MAX] m_data;
	uint m_write = 0, m_read = 0;

    bool push(T item) {
		uint next = (m_write + 1) % MAX;
		if(next != m_read) {
			m_data[m_write] = item;
			m_write = next;
			return true;
		}
		return false;
	}

    bool pop(out T result) {
		if(m_read == m_write) return false;
		uint next = (m_read + 1) % MAX;
		result = m_data[m_read];
		m_read = next;
		return true;
    }
}

// a very fast 'random' number generator
struct GameRand {
    uint high = 12395235;
    uint low = 0x49616e43;
    uint opCall() {
        high = (high << 16) + (high >> 16) + low;
        low += high;
        return high;
    }
    real frac() {
        this.opCall();
        return cast(real)high * (1.0 / 4294967296.0);
    }
    real dfrac() {
        this.opCall();
        return 1.0 - (cast(real)high * (2.0 / 4294967296.0));
    }
    uint seed() {
        return high;
    }
    void seed(uint seed) {
        high = seed;
        low = seed ^ 0x49616e42;
    }
}

// a 'random' number generator based on two numbers
double findnoise2(double x, double y) {
    int n = cast(int)x + cast(int)y*57;
    n = (n << 13) ^ n;
    int nn = (n * (n*n*60493 + 19990303) + 1376312589) & 0x7fffffff;
    return 1.0 - (cast(double)nn / 1073741824.0);
}

struct Vec2D {
    float x;
    float y;

    Vec2D normalized() {
        float l = sqrt(x*x + y*y);
        return l > 0 ? Vec2D(x / l, y / l) : Vec2D(0, 0);
    }

    Vec2D opMul(float s) {
        return Vec2D(x * s, y * s);
    }
	alias opMul opMul_r;
    
	Vec2D opAdd(float a) {
		return Vec2D(x + a, y + a);
	}
	
    Vec2D opAdd(Vec2D b) {
    	return Vec2D(x + b.x, y + b.y);
    }
	
    Vec2D opSub(Vec2D b) {
    	return Vec2D(x - b.x, y - b.y);
    }
	
    Vec2D opSub(float s) {
    	return Vec2D(x - s, y - s);
    }
    
	Vec2D opDiv(float d) {
    	return Vec2D(x / d, y / d);
	}

    void opAddAssign(Vec2D b) {
    	x += b.x;
    	y += b.y;
    }

	float* ptr() {
		return cast(float*)this;
	}

	float[] opSlice() {
		return [x, y];
	}
}

struct Vec3D {
	float x;
	float y;
	float z;

	Vec3D normalized() {
        float l = sqrt(x*x + y*y + z*z);
        return l > 0 ? Vec3D(x / l, y / l, z / l) : Vec3D(0, 0, 0);
	}

	Vec3D opMul(float s) {
		return Vec3D(x * s, y * s, z * s);
	}

	Vec3D opAdd(float a) {
		return Vec3D(x + a, y + a, z + a);
	}

	float* ptr() {
		return cast(float*)this;
	}

	float[] opSlice() {
		return [x, y, z];
	}
}

struct Vec4D {
    float x;
    float y;
    float z;
    float w;

    Vec4D opAdd(Vec4D o) {
        return Vec4D(x + o.x, y + o.y, z + o.z, w + o.w);
    }

    Vec4D opMul(float s) {
        return Vec4D(x * s, y * s, z * s, w *s);
    }
}

ubyte[] open(char[] path) {
    path = path;
    auto f = new File("../base/" ~ path);
    return cast(ubyte[])f.read();
}

char[] open_text(char[] path) {
    path = path;
    auto f = new File("../base/" ~ path);
    return cast(char[])f.read();
}

char* toStringz(char[] s) {
    if(s.ptr)
        if(!(s.length && s[$-1] is 0))
            s = s ~ '\0';
    return s.ptr;
}

