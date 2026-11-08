import Toybox.Graphics;
import Toybox.Lang;

// Slanted seven-segment digits drawn as polygons, so they scale freely.
module Digits {

    const SLANT = 0.14;
    const THICK = 0.26;
    const GAP = 0.05;

    // Left edge of each "HH:MM" glyph, in digit widths.
    const COLUMNS = [0.0, 1.4, 3.4, 4.8] as Array<Float>;
    const TOTAL_WIDTH = 5.8;

    // Segment bits: a=1 b=2 c=4 d=8 e=16 f=32 g=64.
    const MASKS = [63, 6, 91, 79, 102, 109, 125, 7, 127, 111] as Array<Number>;

    // Segment endpoints in digit units (1 wide, 2 tall), in bit order a..g.
    const ENDS = [
        [0.0, 0.0, 1.0, 0.0],
        [1.0, 0.0, 1.0, 1.0],
        [1.0, 1.0, 1.0, 2.0],
        [0.0, 2.0, 1.0, 2.0],
        [0.0, 1.0, 0.0, 2.0],
        [0.0, 0.0, 0.0, 1.0],
        [0.0, 1.0, 1.0, 1.0],
    ] as Array<Array<Float>>;

    var _shapes as Array<Array<Array<Float>>>? = null;

    // Hexagonal segment outlines, built once.
    function shapes() as Array<Array<Array<Float>>> {
        var cached = _shapes;
        if (cached != null) {
            return cached;
        }
        var built = [] as Array<Array<Array<Float>>>;
        var h = THICK / 2.0;
        for (var i = 0; i < ENDS.size(); i++) {
            var e = ENDS[i];
            var x1 = e[0], y1 = e[1], x2 = e[2], y2 = e[3];
            if (y1 == y2) {
                x1 += GAP;
                x2 -= GAP;
                built.add([[x1, y1], [x1 + h, y1 - h], [x2 - h, y1 - h], [x2, y1], [x2 - h, y1 + h], [x1 + h, y1 + h]]);
            } else {
                y1 += GAP;
                y2 -= GAP;
                built.add([[x1, y1], [x1 + h, y1 + h], [x1 + h, y2 - h], [x1, y2], [x1 - h, y2 - h], [x1 - h, y1 + h]]);
            }
        }
        _shapes = built;
        return built;
    }

    // Draws "HH:MM" centered on (cx, cy); unit is the digit width in pixels.
    // A blank leading hour digit is passed as -1.
    function drawTime(dc as Dc, digits as Array<Number>, cx as Float, cy as Float, unit as Float, outline as Boolean) as Void {
        var left = cx - TOTAL_WIDTH * unit / 2.0;
        for (var i = 0; i < 4; i++) {
            if (digits[i] >= 0) {
                drawDigit(dc, digits[i], left + COLUMNS[i] * unit, cy, unit, outline);
            }
        }
        drawColon(dc, cx, cy, unit, outline);
    }

    function drawDigit(dc as Dc, value as Number, x as Float, cy as Float, unit as Float, outline as Boolean) as Void {
        var mask = MASKS[value];
        var segs = shapes();
        for (var s = 0; s < 7; s++) {
            if ((mask & (1 << s)) != 0) {
                var poly = segs[s];
                var pts = new [poly.size()] as Array<[Numeric, Numeric]>;
                for (var p = 0; p < poly.size(); p++) {
                    var ux = poly[p][0];
                    var uy = poly[p][1];
                    pts[p] = [x + (ux + (1.0 - uy) * SLANT) * unit, cy + (uy - 1.0) * unit];
                }
                drawShape(dc, pts, outline);
            }
        }
    }

    function drawColon(dc as Dc, cx as Float, cy as Float, unit as Float, outline as Boolean) as Void {
        var r = unit * 0.13;
        for (var i = -1; i <= 1; i += 2) {
            var dy = i * unit * 0.45;
            var x = cx - dy * SLANT;
            var y = cy + dy;
            drawShape(dc, [[x, y - r], [x + r, y], [x, y + r], [x - r, y]] as Array<[Numeric, Numeric]>, outline);
        }
    }

    function drawShape(dc as Dc, pts as Array<[Numeric, Numeric]>, outline as Boolean) as Void {
        if (!outline) {
            dc.fillPolygon(pts);
            return;
        }
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var a = pts[i];
            var b = pts[(i + 1) % n];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
    }

    // Time split into four glyphs, honoring the 12/24 hour setting.
    function timeDigits(hour as Number, min as Number, is24Hour as Boolean) as Array<Number> {
        if (!is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var tens = hour / 10;
        if (tens == 0 && !is24Hour) {
            tens = -1;
        }
        return [tens, hour % 10, min / 10, min % 10];
    }
}
