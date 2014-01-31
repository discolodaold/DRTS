module gui;

import util : Vec;

// gui based on offsets from ll sides of the screen and center

public uint screen_width;
public uint screen_height;

enum Side {
    left,
    top,
    right,
    bottom,
    center
}
struct Offset {
    Side side;
    int amount;
}

private class Screen : Widget {
    this(uint _width, uint _height) {
        m_x = Offset(Side.left, 0);
        m_y = Offset(Side.top, 0);
        m_width = _width;
        m_height = _height;
    }

    void left  (int x) { assert(0, "cannot modify screen"); }
    void right (int x) { assert(0, "cannot modify screen"); }
    void top   (int x) { assert(0, "cannot modify screen"); }
    void bottom(int x) { assert(0, "cannot modify screen"); }
}
Screen screen;

abstract class Widget {
    private Widget m_parent;
    private Widget[] m_children;

    private Offset m_x;
    private Offset m_y;
    private uint m_width;
    private uint m_height;

    int left() {
        switch(m_x.side) {
        case Side.left: return m_x.amount + m_parent.left;
        case Side.center: return (m_parent.width / 2) - (m_width / 2);
        case Side.right: return (m_parent.right - m_x.amount) - m_width;
        }
    }
    void left(int x) {
        if(m_x.side == Side.left) {
            m_x.amount = x;
            return;
        }
        if(m_x.side == Side.right) {
            m_width = right - x;
            return;
        }
    }
    int right() {
        return left + m_width;
    }
    void right(int x) {
        if(m_x.side == Side.right) {
            m_x.amount = x;
            return;
        }
        if(m_x.side == Side.left) {
            m_width = x - left;
            return;
        }
    }
    int top() {
        switch(m_x.side) {
        case Side.top: return m_y.amount + m_parent.top;
        case Side.center: return (screen_height / 2) - (m_height / 2);
        case Side.bottom: return (m_parent.top - m_y.amount) - m_height;
        }
    }
    void top(int y) {
        if(m_y.side == Side.top) {
            m_y.amount = y;
            return;
        }
        if(m_y.side == Side.bottom) {
            m_height = bottom - y;
            return;
        }
    }
    int bottom() {
        return top + m_height;
    }
    void bottom(int y) {
        if(m_y.side == Side.bottom) {
            m_y.amount = y;
            return;
        }
        if(m_y.side == Side.bottom) {
            m_height = y - bottom;
            return;
        }
    }

    uint width() { return m_width; }
    void width(uint w) { m_Width = w; }
    uint height() { return m_height; }
    void height(uint h) { m_height = h; }

    Widget opIndex(uint i) {
        return m_children[i];
    }

    void append(Widget w) {
        m_children ~= w;
    }
}

class Label : Widget {
    private char[] m_text = "EMPTY";

    this(char[] _text) {
        m_text = text;
    }

    char[] text() { return m_text; }
    void text(char[] _text) { m_text = _text; }


}

