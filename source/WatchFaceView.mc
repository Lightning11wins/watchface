import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// "Warp Jump": a hyperspace burst on every wrist raise, then a calm orbit.
class WatchFaceView extends WatchUi.WatchFace {

    // Timeline, in ms since wake.
    const WARP_END = 1100;
    const GLOW_START = 850;
    const FLASH_END = 1200;
    const INVERT_END = 1280;
    const SLAM_START = 1200;
    const SLAM_END = 1600;
    const IMPACT = 1420;
    const SHAKE_END = 1580;
    const GLITCH_END = 1850;
    const PLANET_START = 1300;
    const PLANET_END = 2000;
    const RING_END = 2100;
    const DATE_START = 1650;

    const FRAME_MS = 50;
    const STAR_COUNT = 48;
    const FOCAL = 70.0;
    const DIGIT_UNIT = 24.0;
    const ORBITERS = 3;

    var _timer as Timer.Timer?;
    var _awake as Boolean = true;
    var _wakeMs as Number = 0;
    var _lastFrameMs as Number = 0;
    var _lastSec as Number = -1;
    var _secMarkMs as Number = 0;
    var _partialAllowed as Boolean = true;

    var _starX as Array<Float>;
    var _starY as Array<Float>;
    var _starZ as Array<Float>;

    var _planet as BitmapResource?;
    var _sub as [Number, Number, Number, Number] = [113, 0, 62, 62];

    function initialize() {
        WatchFace.initialize();
        _starX = new [STAR_COUNT] as Array<Float>;
        _starY = new [STAR_COUNT] as Array<Float>;
        _starZ = new [STAR_COUNT] as Array<Float>;
        for (var i = 0; i < STAR_COUNT; i++) {
            respawnStar(i, rnd(0.1, 1.0));
        }
    }

    function onLayout(dc as Dc) as Void {
        _planet = WatchUi.loadResource(Rez.Drawables.Planet) as BitmapResource;
        var box = WatchUi.getSubscreen();
        if (box != null) {
            _sub = [box.x, box.y, box.width, box.height];
        }
    }

    function onShow() as Void {
        startWarp();
    }

    function onHide() as Void {
        stopTimer();
    }

    function onExitSleep() as Void {
        startWarp();
    }

    function onEnterSleep() as Void {
        _awake = false;
        stopTimer();
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onPowerBudgetExceeded() as Void {
        _partialAllowed = false;
    }

    function onUpdate(dc as Dc) as Void {
        dc.clearClip();
        var now = System.getTimer();
        var clock = System.getClockTime();
        trackSecond(clock.sec, now);

        if (!_awake) {
            drawRestingFace(dc, clock);
            return;
        }

        var t = now - _wakeMs;
        var dt = (now - _lastFrameMs).toFloat() / 1000.0;
        _lastFrameMs = now;
        if (dt > 0.1) {
            dt = 0.1;
        }

        var w = dc.getWidth().toFloat();
        var h = dc.getHeight().toFloat();
        var cx = w / 2.0;
        var cy = h / 2.0 + 8.0;

        if (t >= WARP_END && t < FLASH_END) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.clear();
            return;
        }

        var inverted = t >= FLASH_END && t < INVERT_END;
        var fg = inverted ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        var bg = inverted ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(fg, bg);
        dc.clear();

        if (t >= IMPACT && t < SHAKE_END) {
            var amp = 4.0 * (SHAKE_END - t) / (SHAKE_END - IMPACT);
            cx += rnd(-amp, amp);
            cy += rnd(-amp, amp);
        }

        var speed = starSpeed(t);
        moveStars(speed * dt, w, h);
        drawStars(dc, cx, cy - 8.0, speed);

        if (t >= GLOW_START && t < WARP_END) {
            var q = (t - GLOW_START).toFloat() / (WARP_END - GLOW_START);
            dc.fillCircle(cx, cy - 8.0, 130.0 * q * q);
        }

        drawShockwave(dc, t, cx, cy);

        if (t >= PLANET_START && !inverted) {
            var p = clamp01((t - PLANET_START).toFloat() / (PLANET_END - PLANET_START));
            drawPlanet(dc, h, easeOutCubic(p));
        }

        var digits = Digits.timeDigits(clock.hour, clock.min, System.getDeviceSettings().is24Hour);
        if (t >= SLAM_START) {
            drawOrbiters(dc, t, cx, cy, false, bg);
            drawSlamDigits(dc, t, digits, cx, cy, w);
            drawOrbiters(dc, t, cx, cy, true, bg);
        }
        if (t >= DATE_START) {
            drawDate(dc, t - DATE_START);
        }
        drawSubscreen(dc, clock.sec, now, t < SLAM_END ? t : -1, fg, bg);
    }

    function onPartialUpdate(dc as Dc) as Void {
        if (!_partialAllowed) {
            return;
        }
        var now = System.getTimer();
        trackSecond(System.getClockTime().sec, now);
        dc.setClip(_sub[0], _sub[1], _sub[2], _sub[3]);
        drawSubscreen(dc, _lastSec, now, -1, Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clearClip();
    }

    // Low power frame: frozen starfield, landed planet and digits.
    function drawRestingFace(dc as Dc, clock as ClockTime) as Void {
        var w = dc.getWidth().toFloat();
        var h = dc.getHeight().toFloat();
        var cx = w / 2.0;
        var cy = h / 2.0 + 8.0;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        drawStars(dc, cx, cy - 8.0, 0.0);
        drawPlanet(dc, h, 1.0);
        var digits = Digits.timeDigits(clock.hour, clock.min, System.getDeviceSettings().is24Hour);
        Digits.drawTime(dc, digits, cx, cy, DIGIT_UNIT, false);
        drawDate(dc, 10000);
        drawSubscreen(dc, clock.sec, System.getTimer(), -1, Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    }

    function startWarp() as Void {
        _awake = true;
        _wakeMs = System.getTimer();
        _lastFrameMs = _wakeMs;
        for (var i = 0; i < STAR_COUNT; i++) {
            respawnStar(i, rnd(0.15, 1.0));
        }
        stopTimer();
        var timer = new Timer.Timer();
        timer.start(method(:onTick), FRAME_MS, true);
        _timer = timer;
        WatchUi.requestUpdate();
    }

    function stopTimer() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    function trackSecond(sec as Number, now as Number) as Void {
        if (sec != _lastSec) {
            _lastSec = sec;
            _secMarkMs = now;
        }
    }

    // Star speed in depth units per second: ramps into warp, then brakes hard.
    function starSpeed(t as Number) as Float {
        if (t < WARP_END) {
            var p = t.toFloat() / WARP_END;
            return 0.4 + 7.0 * Math.pow(p, 2.5).toFloat();
        }
        return 0.12 + 7.4 * Math.pow(Math.E, -(t - WARP_END) / 250.0).toFloat();
    }

    function respawnStar(i as Number, z as Float) as Void {
        _starX[i] = rnd(-1.0, 1.0);
        _starY[i] = rnd(-1.0, 1.0);
        _starZ[i] = z;
    }

    function moveStars(dz as Float, w as Float, h as Float) as Void {
        var limit = w > h ? w : h;
        for (var i = 0; i < STAR_COUNT; i++) {
            var z = _starZ[i] - dz;
            var reach = (_starX[i].abs() > _starY[i].abs() ? _starX[i].abs() : _starY[i].abs()) / z * FOCAL;
            if (z < 0.04 || reach > limit) {
                respawnStar(i, rnd(0.8, 1.0));
            } else {
                _starZ[i] = z;
            }
        }
    }

    // Stars as streaks whose length tracks speed; near stars draw thicker.
    function drawStars(dc as Dc, cx as Float, cy as Float, speed as Float) as Void {
        var trail = speed * 0.06;
        for (var i = 0; i < STAR_COUNT; i++) {
            var z = _starZ[i];
            var x = cx + _starX[i] / z * FOCAL;
            var y = cy + _starY[i] / z * FOCAL;
            var near = z < 0.3;
            if (trail < 0.004) {
                if (near) {
                    dc.fillRectangle(x, y, 2, 2);
                } else {
                    dc.drawPoint(x, y);
                }
                continue;
            }
            var tz = z + trail;
            dc.setPenWidth(near ? 2 : 1);
            dc.drawLine(cx + _starX[i] / tz * FOCAL, cy + _starY[i] / tz * FOCAL, x, y);
        }
        dc.setPenWidth(1);
    }

    function drawShockwave(dc as Dc, t as Number, cx as Float, cy as Float) as Void {
        for (var k = 0; k < 2; k++) {
            var start = IMPACT + k * 120;
            if (t < start || t >= RING_END) {
                continue;
            }
            var p = (t - start).toFloat() / (RING_END - start);
            var width = (7.0 * (1.0 - p)).toNumber() + 1;
            dc.setPenWidth(width);
            dc.drawCircle(cx, cy, 18.0 + 150.0 * easeOutCubic(p));
        }
        dc.setPenWidth(1);
    }

    function drawPlanet(dc as Dc, h as Float, p as Float) as Void {
        var planet = _planet;
        if (planet == null) {
            return;
        }
        var rest = h - planet.getHeight();
        dc.drawBitmap(0, rest + (1.0 - p) * planet.getHeight(), planet);
    }

    // Digits fall from 3x scale with an overshoot, trailed by outline echoes,
    // then glitch briefly after landing.
    function drawSlamDigits(dc as Dc, t as Number, digits as Array<Number>, cx as Float, cy as Float, w as Float) as Void {
        if (t < SLAM_END) {
            var p = (t - SLAM_START).toFloat() / (SLAM_END - SLAM_START);
            var scale = 1.0 + 2.0 * (1.0 - easeOutBack(p));
            if (p < 0.7) {
                Digits.drawTime(dc, digits, cx, cy, DIGIT_UNIT * scale * 1.45, true);
                Digits.drawTime(dc, digits, cx, cy, DIGIT_UNIT * scale * 1.2, true);
            }
            Digits.drawTime(dc, digits, cx, cy, DIGIT_UNIT * scale, false);
            return;
        }
        if (t >= GLITCH_END) {
            Digits.drawTime(dc, digits, cx, cy, DIGIT_UNIT, false);
            return;
        }
        var bands = 5;
        var top = cy - DIGIT_UNIT - 4.0;
        var bandH = Math.ceil((2.0 * DIGIT_UNIT + 8.0) / bands).toNumber();
        for (var i = 0; i < bands; i++) {
            var shift = Math.rand() % 3 == 0 ? rnd(-9.0, 9.0) : 0.0;
            dc.setClip(0, top.toNumber() + i * bandH, w.toNumber(), bandH);
            Digits.drawTime(dc, digits, cx + shift, cy, DIGIT_UNIT, false);
        }
        dc.clearClip();
    }

    // Moons on a tilted ellipse, passing behind and in front of the digits.
    function drawOrbiters(dc as Dc, t as Number, cx as Float, cy as Float, front as Boolean, bg as Number) as Void {
        var spin = t.toFloat() / 1000.0 * 1.6;
        var fg = bg == Graphics.COLOR_BLACK ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        for (var i = 0; i < ORBITERS; i++) {
            var a = spin + i * 2.0944;
            var depth = Math.sin(a);
            if ((depth > 0) != front) {
                continue;
            }
            for (var k = 3; k >= 1; k--) {
                var pt = orbitPoint(a - k * 0.13, cx, cy);
                dc.drawPoint(pt[0], pt[1]);
            }
            var head = orbitPoint(a, cx, cy);
            var r = 2.5 + 1.5 * depth;
            if (front) {
                dc.setColor(bg, bg);
                dc.fillCircle(head[0], head[1], r + 1.5);
                dc.setColor(fg, bg);
            }
            dc.fillCircle(head[0], head[1], r);
        }
    }

    function orbitPoint(a as Float, cx as Float, cy as Float) as [Float, Float] {
        var x = 82.0 * Math.cos(a);
        var y = 15.0 * Math.sin(a) - x * 0.14;
        return [cx + x, cy + 4.0 + y];
    }

    // Day and date, typed on one letter at a time.
    function drawDate(dc as Dc, elapsed as Number) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var text = (info.day_of_week + " " + info.day).toUpper();
        var shown = elapsed / 45;
        if (shown < text.length()) {
            text = text.substring(0, shown) + "_";
        }
        dc.drawText(_sub[0] / 2, 30, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Subscreen: spinning charge arcs while warping, else a seconds ring.
    function drawSubscreen(dc as Dc, sec as Number, now as Number, warpT as Number, fg as Number, bg as Number) as Void {
        var bx = _sub[0], by = _sub[1], bw = _sub[2], bh = _sub[3];
        var x = bx + bw / 2;
        var y = by + bh / 2;
        var r = bw / 2 - 4;
        dc.setColor(bg, bg);
        dc.fillRectangle(bx, by, bw, bh);
        dc.setColor(fg, bg);

        if (warpT >= 0) {
            var turn = (warpT * warpT / 900) % 360;
            dc.setPenWidth(3);
            for (var k = 0; k < 4; k++) {
                var start = turn + k * 90;
                dc.drawArc(x, y, r, Graphics.ARC_COUNTER_CLOCKWISE, start % 360, (start + 50) % 360);
            }
            dc.setPenWidth(1);
            dc.drawText(x, y, Graphics.FONT_XTINY, "WARP", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        for (var i = 0; i < 12; i++) {
            var a = i * Math.PI / 6.0;
            dc.drawPoint(x + (r + 2) * Math.sin(a), y - (r + 2) * Math.cos(a));
        }
        if (sec > 0) {
            dc.setPenWidth(3);
            dc.drawArc(x, y, r - 2, Graphics.ARC_CLOCKWISE, 90, (450 - sec * 6) % 360);
            dc.setPenWidth(1);
        }
        var ha = sec * Math.PI / 30.0;
        dc.fillCircle(x + (r - 2) * Math.sin(ha), y - (r - 2) * Math.cos(ha), 3);

        if (_awake) {
            var frac = clamp01((now - _secMarkMs).toFloat() / 1000.0);
            dc.drawCircle(x, y, 6.0 + (r - 10) * frac);
        }
        dc.drawText(x, y, Graphics.FONT_NUMBER_MILD, sec.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function rnd(lo as Float, hi as Float) as Float {
        return lo + (Math.rand() % 10000) / 10000.0 * (hi - lo);
    }

    function clamp01(v as Float) as Float {
        return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
    }

    function easeOutCubic(p as Float) as Float {
        var q = 1.0 - p;
        return 1.0 - q * q * q;
    }

    function easeOutBack(p as Float) as Float {
        var c1 = 1.70158;
        var c3 = c1 + 1.0;
        var q = p - 1.0;
        return 1.0 + c3 * q * q * q + c1 * q * q;
    }
}

class WatchFaceDelegate extends WatchUi.WatchFaceDelegate {

    var _view as WatchFaceView;

    function initialize(view as WatchFaceView) {
        WatchUi.WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPowerBudgetExceeded(powerInfo as WatchUi.WatchFacePowerInfo) as Void {
        _view.onPowerBudgetExceeded();
    }
}
