"""Genel pencere çizim motoru: ağaç yapısından SVG. Katalog için çok sayıda tip üretir."""
import math, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from draw import glass, symbol, handle, dims_h, dims_v, svg, frange, AMBER, uid
import draw

COLORS = {
    'beyaz':   ['#FFFFFF', '#E3ECEE', '#C9D7DA', '#EEF4F5'],
    'krem':    ['#FBF6E9', '#EFE6D0', '#DFD3B6', '#F5EEDB'],
    'antrasit': ['#5A6166', '#464C51', '#383D41', '#50565B'],
    'altinmese': ['#C88A4A', '#AE723A', '#94602F', '#BC7F42'],
    'ceviz':   ['#7A4E31', '#663F27', '#55341F', '#70472C'],
}
F, M, S = 26, 20, 22   # kasa, kayıt, kanat yüz genişliği (px)


def ring(o, i, cols, stroke='#9FB1B5'):
    return draw.ring(o, i, cols, stroke)


class R:
    def __init__(s, cols):
        s.c = cols
        s.out = ''

    def mull(s, x, y, w, h):
        s.out += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{s.c[0]}" stroke="#9FB1B5"/>'

    def node(s, n, box):
        l, t, r, b = box
        k = n[0]
        if k == 'fix':
            o = n[1] if len(n) > 1 else {}
            s.out += glass((l + 6, t + 6, r - 6, b - 6), panel=o.get('panel', False))
            s.extras(o, (l + 6, t + 6, r - 6, b - 6))
        elif k == 'sash':
            kind = n[1]
            o = n[2] if len(n) > 2 else {}
            s.sash(box, kind, o)
        elif k in ('v', 'h'):
            sizes, kids = n[1], n[2]
            tot = sum(sizes)
            span = (r - l) if k == 'v' else (b - t)
            avail = span - M * (len(kids) - 1)
            pos = l if k == 'v' else t
            for i, (sz, kid) in enumerate(zip(sizes, kids)):
                d = avail * sz / tot
                sub = (pos, t, pos + d, b) if k == 'v' else (l, pos, r, pos + d)
                s.node(kid, sub)
                pos += d
                if i < len(kids) - 1:
                    if k == 'v':
                        s.mull(pos, t, M, b - t)
                    else:
                        s.mull(l, pos, r - l, M)
                    pos += M
        elif k == 'slide':
            s.slide(box, n[1], n[2] if len(n) > 2 else {})

    def extras(s, o, gb):
        l, t, r, b = gb
        if o.get('mesh'):
            s.out += ''.join(f'<line x1="{x}" y1="{t}" x2="{x}" y2="{b}" stroke="#5E7A80" stroke-width=".7" opacity=".45"/>' for x in frange(l + 6, r, 8))
            s.out += ''.join(f'<line x1="{l}" y1="{y}" x2="{r}" y2="{y}" stroke="#5E7A80" stroke-width=".7" opacity=".45"/>' for y in frange(t + 6, b, 8))
        if o.get('grid'):
            cx, cy = o['grid']
            for i in range(1, cx):
                x = l + (r - l) * i / cx
                s.out += f'<rect x="{x-2.5}" y="{t}" width="5" height="{b-t}" fill="{s.c[0]}" stroke="#B9C7CA" stroke-width=".8"/>'
            for j in range(1, cy):
                y = t + (b - t) * j / cy
                s.out += f'<rect x="{l}" y="{y-2.5}" width="{r-l}" height="5" fill="{s.c[0]}" stroke="#B9C7CA" stroke-width=".8"/>'

    def sash(s, box, kind, o):
        lap = 3
        door = o.get('door', False)
        face = S * (1.3 if door else 1)
        so = (box[0] - lap, box[1] - lap, box[2] + lap, box[3] + lap)
        si = (so[0] + face, so[1] + face, so[2] - face, so[3] - face)
        s.out += ring(so, si, s.c)
        gb = (si[0] + 5, si[1] + 5, si[2] - 5, si[3] - 5)
        pb = o.get('panel_bottom')
        if o.get('panel'):
            s.out += glass(gb, panel=True)
            if o.get('window'):
                wl, wt = (gb[0] + gb[2]) / 2 - 18, gb[1] + 30
                s.out += glass((wl, wt, wl + 36, wt + (gb[3] - gb[1]) * .35))
        elif pb:
            mid = gb[3] - (gb[3] - gb[1]) * pb
            s.out += glass((gb[0], gb[1], gb[2], mid - 10))
            s.out += f'<rect x="{si[0]}" y="{mid-10}" width="{si[2]-si[0]}" height="20" fill="{s.c[3]}" stroke="#9FB1B5"/>'
            s.out += glass((gb[0], mid + 10, gb[2], gb[3]), panel=True)
            s.extras(o, (gb[0], gb[1], gb[2], mid - 10))
        else:
            s.out += glass(gb)
            s.extras(o, gb)
        sym = symbol(gb, kind)
        if o.get('out'):
            sym = sym.replace('stroke-linecap="round"', 'stroke-linecap="round" stroke-dasharray="9 6"')
        s.out += sym
        cy = (so[1] + so[3]) / 2
        if kind in ('turnL', 'ttL'):
            s.out += handle(so[2] - face / 2, cy)
        elif kind in ('turnR', 'ttR'):
            s.out += handle(so[0] + face / 2, cy)
        elif kind == 'tilt':
            s.out += handle((so[0] + so[2]) / 2, so[1] + face / 2, horizontal=True)
        if door and kind in ('turnL', 'turnR'):
            hx = so[2] - face / 2 if kind == 'turnL' else so[0] + face / 2
            s.out += f'<circle cx="{hx}" cy="{cy+40}" r="5" fill="#6F7D81"/>'

    def slide(s, box, moves, o):
        l, t, r, b = box
        n, il = len(moves), 14
        pw = (r - l + (n - 1) * il) / n
        for k, mv in enumerate(moves):
            x = l + k * (pw - il)
            so = (x, t, x + pw, b)
            si = (so[0] + S, so[1] + S, so[2] - S, so[3] - S)
            s.out += ring(so, si, s.c) + glass(si)
            cy = (si[1] + si[3]) / 2
            mx = (si[0] + si[2]) / 2
            if mv == 'f':
                s.out += f'<text x="{mx}" y="{cy+5}" fill="#2F5D66" font-size="14" font-weight="700" text-anchor="middle">SABİT</text>'
            else:
                d = 1 if mv == 'r' else -1
                L = min(45, (si[2] - si[0]) * .32)
                x1, x2 = mx - d * L, mx + d * L
                s.out += (f'<polyline points="{x1},{cy} {x2},{cy}" stroke="{AMBER}" stroke-width="3.5" fill="none"/>'
                          f'<polyline points="{x2-d*13},{cy-9} {x2},{cy} {x2-d*13},{cy+9}" stroke="{AMBER}" stroke-width="3.5" fill="none" stroke-linejoin="round"/>')
                if o.get('lift'):
                    s.out += (f'<polyline points="{mx},{cy+38} {mx},{cy+14}" stroke="{AMBER}" stroke-width="3" fill="none"/>'
                              f'<polyline points="{mx-8},{cy+22} {mx},{cy+14} {mx+8},{cy+22}" stroke="{AMBER}" stroke-width="3" fill="none"/>')
            if o.get('mesh') and k == 0:
                s.extras({'mesh': 1}, si)


def window(Wmm, Hmm, tree, color='beyaz', threshold=False, shutter=False, sill=False, label=None):
    cols = COLORS[color]
    maxpx = 420
    sc = maxpx / max(Wmm, Hmm)
    W, H = Wmm * sc, Hmm * sc
    box = 62 if shutter else 0
    x0, y0 = 56, 22 + box + (16 if shutter else 0)
    rr = R(cols)
    out = ''
    if shutter:
        by = y0 - box
        out += (f'<rect x="{x0}" y="{by}" width="{W}" height="{box}" rx="3" fill="#8C9A9E" stroke="#6F7D81"/>'
                + ''.join(f'<line x1="{x0+6}" y1="{y}" x2="{x0+W-6}" y2="{y}" stroke="#B7C2C5" stroke-width="2"/>' for y in frange(by + 9, y0 - 3, 9))
                + f'<rect x="{x0-7}" y="{by}" width="7" height="{H+box}" fill="#A9B5B8"/><rect x="{x0+W}" y="{by}" width="7" height="{H+box}" fill="#A9B5B8"/>')
    o = (x0, y0, x0 + W, y0 + H)
    if threshold:
        i = (x0 + F, y0 + F, x0 + W - F, y0 + H - 9)
        out += (f'<polygon points="{o[0]},{o[1]} {o[2]},{o[1]} {i[2]},{i[1]} {i[0]},{i[1]}" fill="{cols[0]}" stroke="#9FB1B5"/>'
                f'<polygon points="{o[2]},{o[1]} {o[2]},{i[3]} {i[2]},{i[3]} {i[2]},{i[1]}" fill="{cols[1]}" stroke="#9FB1B5"/>'
                f'<polygon points="{o[0]},{i[3]} {o[0]},{o[1]} {i[0]},{i[1]} {i[0]},{i[3]}" fill="{cols[3]}" stroke="#9FB1B5"/>'
                f'<rect x="{x0}" y="{y0+H-9}" width="{W}" height="9" fill="#B8C4C7" stroke="#8A9A9E"/>')
    else:
        i = (x0 + F, y0 + F, x0 + W - F, y0 + H - F)
        out += ring(o, i, cols)
    rr.node(tree, i)
    out += rr.out
    if sill:
        out += f'<rect x="{x0-16}" y="{y0+H}" width="{W+32}" height="11" fill="#D9E1E3" stroke="#9FB1B5"/>'
    dy = y0 + H + (40 if sill else 30)
    out += dims_h(x0, x0 + W, dy, str(Wmm)) + dims_v(x0 - 26, y0 - box, y0 + H, str(Hmm + (0 if not shutter else 0)))
    return svg(out, f'0 0 {x0 + W + 30} {dy + 34}')


def coupled(parts, gap_color='#DCE5E7', color='beyaz'):
    """Birleşik: [(Wmm,Hmm,tree,threshold)] yan yana, altları hizalı."""
    cols = COLORS[color]
    Ht = max(p[1] for p in parts)
    Wt = sum(p[0] for p in parts)
    sc = 440 / max(Wt, Ht)
    x, y0, out = 56, 22, ''
    for (w, h, tree, th) in parts:
        W, H = w * sc, h * sc
        top = y0 + (Ht - h) * sc
        o = (x, top, x + W, top + H)
        if th:
            i = (x + F, top + F, x + W - F, top + H - 9)
            out += (f'<polygon points="{o[0]},{o[1]} {o[2]},{o[1]} {i[2]},{i[1]} {i[0]},{i[1]}" fill="{cols[0]}" stroke="#9FB1B5"/>'
                    f'<polygon points="{o[2]},{o[1]} {o[2]},{i[3]} {i[2]},{i[3]} {i[2]},{i[1]}" fill="{cols[1]}" stroke="#9FB1B5"/>'
                    f'<polygon points="{o[0]},{i[3]} {o[0]},{o[1]} {i[0]},{i[1]} {i[0]},{i[3]}" fill="{cols[3]}" stroke="#9FB1B5"/>'
                    f'<rect x="{x}" y="{top+H-9}" width="{W}" height="9" fill="#B8C4C7" stroke="#8A9A9E"/>')
        else:
            i = (x + F, top + F, x + W - F, top + H - F)
            out += ring(o, i, cols)
        rr = R(cols); rr.node(tree, i); out += rr.out
        out += dims_h(x, x + W, y0 + Ht * sc + 30, str(w))
        x += W
    xs, x = [], 56
    for (w, h, _, _) in parts[:-1]:
        x += w * sc
        hh = min(h, parts[len(xs) + 1][1]) * sc
        out += f'<rect x="{x-5}" y="{y0+Ht*sc-hh}" width="10" height="{hh}" fill="{gap_color}" stroke="#9FB1B5"/>'
        xs.append(x)
    out += dims_v(30, y0, y0 + Ht * sc, str(Ht))
    return svg(out, f'0 0 {56 + Wt*sc + 30} {y0 + Ht*sc + 64}')


def shaped(kind, Wmm, Hmm, tree=None, color='beyaz', rise=None):
    """kind: arch (yarım kemer), seg (basık kemer), tri (üçgen), trap (eğik). tree alt dikdörtgen bölgeye çizilir."""
    cols = COLORS[color]
    sc = 420 / max(Wmm, Hmm)
    W, H = Wmm * sc, Hmm * sc
    x0, y0 = 56, 22
    out = ''
    if kind in ('arch', 'seg'):
        rise_px = W / 2 if kind == 'arch' else (rise or Wmm * .18) * sc
        R_ = (W * W / 4 + rise_px * rise_px) / (2 * rise_px)
        spring = y0 + rise_px
        Ri = R_ - F
        cx, cyc = x0 + W / 2, y0 + R_
        # iç yay kirişi
        def arc(r_, l, rgt, ys):
            return f'A {r_},{r_} 0 0 1 {rgt},{ys}'
        xi_l, xi_r = x0 + F, x0 + W - F
        yi = cyc - math.sqrt(max(Ri * Ri - (W / 2 - F) ** 2, 0))
        outer = f'M {x0},{y0+H} L {x0},{spring} A {R_},{R_} 0 0 1 {x0+W},{spring} L {x0+W},{y0+H} Z'
        inner = f'M {xi_l},{y0+H-F} L {xi_l},{yi} A {Ri},{Ri} 0 0 1 {xi_r},{yi} L {xi_r},{y0+H-F} Z'
        out += f'<path d="{outer} {inner}" fill-rule="evenodd" fill="{cols[3]}" stroke="#9FB1B5" stroke-width="1.2"/>'
        out += f'<path d="M {x0},{spring} A {R_},{R_} 0 0 1 {x0+W},{spring} L {xi_r},{yi} A {Ri},{Ri} 0 0 0 {xi_l},{yi} Z" fill="{cols[0]}" stroke="#9FB1B5"/>'
        split = max(spring, yi) + 14
        g = 7
        Rg = Ri - g
        yg = cyc - math.sqrt(max(Rg * Rg - (W / 2 - F - g) ** 2, 0))
        clip = f'<path d="M {xi_l+g},{split} L {xi_l+g},{yg} A {Rg},{Rg} 0 0 1 {xi_r-g},{yg} L {xi_r-g},{split} Z"/>'
        if tree:
            out += glass((xi_l + g, cyc - Rg, xi_r - g, split), clip_d=clip)
            out += f'<rect x="{xi_l}" y="{split}" width="{xi_r-xi_l}" height="{M}" fill="{cols[0]}" stroke="#9FB1B5"/>'
            rr = R(cols); rr.node(tree, (xi_l, split + M, xi_r, y0 + H - F)); out += rr.out
        else:
            clip = f'<path d="M {xi_l+g},{y0+H-F-g} L {xi_l+g},{yg} A {Rg},{Rg} 0 0 1 {xi_r-g},{yg} L {xi_r-g},{y0+H-F-g} Z"/>'
            out += glass((xi_l + g, cyc - Rg, xi_r - g, y0 + H - F - g), clip_d=clip)
    else:
        if kind == 'tri':
            o = [(x0, y0 + H), (x0 + W / 2, y0), (x0 + W, y0 + H)]
        else:
            hr = (rise or Hmm * .6) * sc
            o = [(x0, y0 + H), (x0, y0), (x0 + W, y0 + H - hr), (x0 + W, y0 + H)]
        out += poly_frame(o, F, cols)
        ins = inset(o, F + 7)
        P = ' '.join(f'{a},{b}' for a, b in ins)
        xs = [p[0] for p in ins]; ys = [p[1] for p in ins]
        out += glass((min(xs), min(ys), max(xs), max(ys)), clip_d=f'<polygon points="{P}"/>')
    out += dims_h(x0, x0 + W, y0 + H + 30, str(Wmm)) + dims_v(x0 - 26, y0, y0 + H, str(Hmm))
    return svg(out, f'0 0 {x0 + W + 30} {y0 + H + 64}')


def inset(pts, d):
    """Saat yönünün tersi / yönü fark etmeksizin içe offset (konveks çokgen)."""
    n = len(pts)
    cx = sum(p[0] for p in pts) / n; cy = sum(p[1] for p in pts) / n
    lines = []
    for k in range(n):
        a, b = pts[k], pts[(k + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nx, ny = -dy / L, dx / L
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if (cx - mx) * nx + (cy - my) * ny < 0:
            nx, ny = -nx, -ny
        lines.append(((a[0] + nx * d, a[1] + ny * d), (dx, dy)))
    out = []
    for k in range(n):
        (p1, d1), (p2, d2) = lines[k - 1], lines[k]
        den = d1[0] * d2[1] - d1[1] * d2[0]
        t = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / den
        out.append((p1[0] + d1[0] * t, p1[1] + d1[1] * t))
    return out


def poly_frame(o, f, cols):
    ii = inset(o, f)
    n = len(o)
    res = ''
    for k in range(n):
        a, b = o[k], o[(k + 1) % n]
        ia, ib = ii[k], ii[(k + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        # yüzey tonu: kenar yönüne göre
        if abs(dy) < 1e-6:
            c = cols[2] if a[1] > o[0][1] - 1 and dx < 0 or a[1] >= max(p[1] for p in o) - 1 else cols[0]
        elif abs(dx) < 1e-6:
            c = cols[1] if dy > 0 else cols[3]
        else:
            c = cols[0]
        res += f'<polygon points="{a[0]},{a[1]} {b[0]},{b[1]} {ib[0]},{ib[1]} {ia[0]},{ia[1]}" fill="{c}" stroke="#9FB1B5"/>'
    return res


# ------------------------------------------------------------------ katalog
fx = ('fix',)
def sh(k, **o): return ('sash', k, o)
def V(sizes, *kids): return ('v', sizes, list(kids))
def Hh(sizes, *kids): return ('h', sizes, list(kids))

CATALOG = [
 # (kod, ad, grup, fonksiyon)
 ('tek_acilir', 'Tek kanat açılır', 'Pencere', lambda: window(700, 1200, sh('ttL'))),
 ('vasistas', 'Vasistas', 'Pencere', lambda: window(900, 600, sh('tilt'))),
 ('sabit', 'Sabit cam', 'Pencere', lambda: window(1000, 1200, fx)),
 ('cift_kayitli', 'Çift kanat, orta kayıtlı', 'Pencere', lambda: window(1400, 1400, V([1, 1], sh('ttL'), sh('turnR')))),
 ('yan_sabit', 'Açılır + yan sabit', 'Pencere', lambda: window(1500, 1400, V([1, 1.3], sh('ttL'), fx))),
 ('uclu', 'Üç bölmeli: ortası sabit', 'Pencere', lambda: window(2100, 1400, V([1, 1.2, 1], sh('ttL'), fx, sh('ttR')))),
 ('ust_vasistas', 'Üstü vasistas, altı çift kanat', 'Pencere', lambda: window(1400, 1700, Hh([1, 2.6], sh('tilt'), V([1, 1], sh('turnL'), sh('ttR'))))),
 ('ust_sabit_alt_vas', 'Üstü sabit, altı vasistas', 'Pencere', lambda: window(1200, 1500, Hh([2.4, 1], fx, sh('tilt')))),
 ('dortlu', 'Dört bölmeli (vasistaslı)', 'Pencere', lambda: window(2400, 1900, Hh([1, 1.9], V([1, 1, 1, 1], sh('tilt'), fx, fx, sh('tilt')), V([1, 1, 1, 1], sh('ttL'), fx, fx, sh('ttR'))))),
 ('vitrin', 'Vitrin (büyük sabit + üst bant)', 'Pencere', lambda: window(2600, 2300, Hh([1, 2.4], V([1, 1, 1], sh('tilt'), fx, sh('tilt')), V([1], fx)))),
 ('dubleks', 'Dubleks çıtalı çift kanat', 'Pencere', lambda: window(1400, 1500, V([1, 1], sh('turnL', grid=(2, 3)), sh('ttR', grid=(2, 3))))),
 ('disa_acilim', 'Dışa açılım', 'Pencere', lambda: window(800, 1100, sh('turnL', out=True))),
 ('sineklikli', 'Sineklikli açılır', 'Pencere', lambda: window(1200, 1300, V([1, 1], fx, sh('ttR', mesh=True)))),
 ('panjurlu_tek', 'Panjurlu çift kanat', 'Pencere', lambda: window(1400, 1500, V([1, 1], sh('ttL'), sh('turnR')), shutter=True, sill=True)),
 ('denizlikli', 'Denizlikli üçlü', 'Pencere', lambda: window(1800, 1200, V([1, 1, 1], sh('ttL'), fx, fx), sill=True)),
 ('balkon_tek', 'Balkon kapısı', 'Kapı', lambda: window(800, 2200, sh('ttL', door=True, panel_bottom=.3), threshold=True)),
 ('servis', 'Servis kapısı (dolu panel)', 'Kapı', lambda: window(900, 2100, sh('turnL', door=True, panel=True, window=True), threshold=True)),
 ('giris_yan', 'Giriş kapısı + yan sabit', 'Kapı', lambda: window(1400, 2200, V([2.2, 1], sh('turnL', door=True, panel_bottom=.45), Hh([2.5, 1], fx, fx)), threshold=True)),
 ('giris_ust', 'Giriş kapısı + üst sabit', 'Kapı', lambda: window(1000, 2500, Hh([1, 4.4], fx, sh('turnL', door=True, panel_bottom=.45)), threshold=True)),
 ('cift_kapi', 'Çift kanat kapı', 'Kapı', lambda: window(1500, 2200, V([1, 1], sh('passive', door=True, panel_bottom=.5), sh('turnR', door=True, panel_bottom=.5)), threshold=True)),
 ('balkon_birlesik', 'Balkon kapısı + pencere', 'Birleşik', lambda: coupled([(800, 2300, sh('ttL', door=True, panel_bottom=.3), True), (1100, 1500, V([1], sh('ttR')), False)])),
 ('balkon_iki_yan', 'Pencere + balkon kapısı + pencere', 'Birleşik', lambda: coupled([(900, 1500, sh('ttL'), False), (800, 2300, sh('ttL', door=True, panel_bottom=.3), True), (900, 1500, sh('ttR'), False)])),
 ('surme2', 'İki kanat sürme', 'Sürme', lambda: window(1800, 1500, ('slide', ['r', 'l']))),
 ('surme4', 'Dört kanat sürme', 'Sürme', lambda: window(3200, 2200, ('slide', ['r', 'f', 'f', 'l']))),
 ('surme_sineklik', 'Sineklikli sürme', 'Sürme', lambda: window(2000, 1500, ('slide', ['r', 'l'], {'mesh': 1}))),
 ('kaldir_sur', 'Kaldır-sür', 'Sürme', lambda: window(3000, 2300, ('slide', ['r', 'f'], {'lift': 1}), threshold=True)),
 ('kemer', 'Yarım kemer', 'Şekilli', lambda: shaped('arch', 1200, 1900, V([1, 1], sh('passive'), sh('ttR')))),
 ('basik_kemer', 'Basık kemer', 'Şekilli', lambda: shaped('seg', 1600, 1700, V([1, 1, 1], sh('ttL'), fx, sh('ttR')), rise=300)),
 ('kemer_sabit', 'Kemerli sabit', 'Şekilli', lambda: shaped('arch', 900, 1500)),
 ('ucgen', 'Üçgen (çatı)', 'Şekilli', lambda: shaped('tri', 1600, 900)),
 ('egik', 'Eğik üst', 'Şekilli', lambda: shaped('trap', 1000, 1500, rise=1000)),
 ('antrasit', 'Antrasit çift kanat', 'Renk', lambda: window(1400, 1400, V([1, 1], sh('ttL'), sh('turnR')), color='antrasit')),
 ('altinmese', 'Altın meşe üçlü', 'Renk', lambda: window(1800, 1400, V([1, 1, 1], sh('ttL'), fx, sh('ttR')), color='altinmese')),
 ('ceviz_kapi', 'Ceviz balkon kapısı', 'Renk', lambda: window(800, 2200, sh('ttL', door=True, panel_bottom=.3), threshold=True, color='ceviz')),
 ('krem', 'Krem vasistaslı', 'Renk', lambda: window(1200, 1500, Hh([1, 2.6], sh('tilt'), V([1, 1], sh('turnL'), sh('ttR'))), color='krem')),
 ('antrasit_surme', 'Antrasit sürme', 'Renk', lambda: window(2400, 2100, ('slide', ['r', 'f', 'l']), color='antrasit')),
]
