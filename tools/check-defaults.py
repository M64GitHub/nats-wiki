#!/usr/bin/env python3
"""Check every documented config default against the nats-server source at a release tag.

    python3 tools/check-defaults.py                       # v2.14.6 -> inbox/check-defaults-v2.14.6.md
    python3 tools/check-defaults.py --tag v2.14.6
    python3 tools/check-defaults.py --only jetstream      # just the keys under one block
    python3 tools/check-defaults.py --src ~/src/nats-server/server   # an existing checkout
    python3 tools/check-defaults.py --explain mqtt.max_ack_pending   # one key, with the evidence

Reads `inbox/config-keys-table.md` (built by `tools/build-config-table.py` from the *generated*
config reference on docs.nats.io) and, for every key whose docs state a default, finds the value
the server actually applies. It emits three lists:

  agrees      the documented default and the resolved server value are the same
  disagrees   they are not — a candidate row for `inbox/docs-issues.md`
  unresolved  the resolver could not reach a value; a human has to read the code

The third list is the honest output, not a failure: it names the key, what was found and where to
look next. **Nothing here is evidence on its own.** `CLAUDE.md` → *Operation: record a docs issue*
still applies in full: verify every disagreement by hand, against the source, with a file and a
line — and run the binary when the claim is behavioural — before it becomes a row.

How a default is resolved. The `via` column always says which, because they are not equally
strong, and the report links the file and line for every one of them:

  assign      a guarded default site in the option parser, `if opts.X == 0 { opts.X = DEFAULT_X }`.
              The strongest: this is the server filling in an unset option.
  use-site    the option is read into a local and defaulted there — `mlen := s.opts.StreamMax…;
              if mlen == 0 { mlen = streamDefault… }`. Just as real, but it means the value never
              appears in the Options struct, so `/varz` will not show it.
  flag-default  the value the command-line flag registers for the same field.
  global      the block does not default the key at all; the server falls back to the top-level
              key of the same name (`cluster.ping_interval` -> `ping_interval`). The documented
              value can be right and the *mechanism* still be worth stating.
  literal     the parse function fills its config struct from a constructor
              (`certidp.NewOCSPPeerConfig()`), and the literal there is the default.
  const-name  no site found, but a constant is named after the field
              (`MQTT.MaxAckPending` <- `mqttDefaultMaxAckPending`). Weakest: the constant may be
              applied somewhere else, or not at all. Read the use site before believing it.
  zero-value  nothing sets it, so Go's zero value stands. Only ever claimed for a documented
              `false`, `0` or empty string, and even then a default can be applied where the field
              is used rather than where it is parsed, so this verdict is a presumption.

The source is the release tarball of the tag, cached under `.cache/` (git-ignored). Nothing is
written to `raw/`: this reads a whole source tree, and `raw/nats-server-src/` deliberately keeps
only the ranges the wiki quotes.
"""
import argparse, ast, glob, os, re, sys, tarfile, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = os.path.join(ROOT, 'inbox', 'config-keys-table.md')
CACHE = os.path.join(ROOT, '.cache')
TARBALL = 'https://github.com/nats-io/nats-server/archive/refs/tags/{tag}.tar.gz'
BLOB = 'https://github.com/nats-io/nats-server/blob/{tag}/server/{file}#L{line}'

# --- what the resolver knows about this codebase's shape ---------------------------------------
# Everything else is derived from the source. These tables are the hand-written part, and the
# reason a key they do not cover lands in `unresolved` rather than being guessed at.

# documented key prefix -> (function that reads those keys, Options field path, roots the field
# is written through). A field path of None means the value lives on a struct this table cannot
# name; matching then falls back to the field name under the listed roots.
BLOCKS = {
    '':                           ('processConfigFileLine',     '',       ('o', 'opts')),
    'cluster':                    ('parseCluster',              'Cluster', ('o', 'opts')),
    'gateway':                    ('parseGateway',              'Gateway', ('o', 'opts')),
    'gateway.gateways':           ('parseGateways',             None,     ('gateway',)),
    'leafnodes':                  ('parseLeafNodes',            'LeafNode', ('o', 'opts')),
    'leafnodes.remotes':          ('parseRemoteLeafNodes',      None,     ('remote', 'r')),
    'jetstream':                  ('parseJetStream',            '',       ('o', 'opts')),
    'jetstream.limits':           ('parseJetStreamLimits',      '',       ('o', 'opts')),
    'jetstream.limits.batch':     ('parseJetStreamLimitsBatch', '',       ('o', 'opts')),
    'websocket':                  ('parseWebsocket',            'Websocket', ('o', 'opts')),
    'mqtt':                       ('parseMQTT',                 'MQTT',   ('o', 'opts')),
    'accounts':                   ('parseAccounts',             None,     ('acc',)),
    'accounts.limits':            ('parseAccountLimits',        None,     ('acc',)),
    'accounts.msg_trace':         ('parseAccountMsgTrace',      None,     ('acc',)),
    'accounts.exports':           ('parseExportStreamOrService', None,    ('export',)),
    'accounts.jetstream':         ('parseJetStreamForAccount',  None,     ('acc',)),
    'authorization':              ('parseAuthorization',        '',       ('o', 'opts')),
    'authorization.auth_callout': ('parseAuthCallout',          None,     ('ac',)),
    'ocsp_cache':                 ('parseOCSPResponseCache',    None,     ('pcfg',)),
    'resolver':                   ('processConfigFileLine',     None,     ('o', 'opts')),
    'resolver_tls':               ('parseTLS',                  None,     ('tc',)),
    'resolver_tls.ocsp_peer':     ('parseOCSPPeer',             None,     ('pcfg',)),
}
# families that repeat under many blocks: (suffix of the documented prefix, parse function)
FAMILIES = [('tls.ocsp_peer', 'parseOCSPPeer'), ('tls', 'parseTLS'),
            ('authorization', 'parseAuthorization'), ('compression', 'parseCompression')]
# a family's parse function writes to a local struct (`tc.Timeout`, `auth.timeout`); this says
# which Options field that local ends up in, so the default site can be found under the block
FAMILY_FIELD = {'tls.timeout': 'TLSTimeout', 'authorization.timeout': 'AuthTimeout',
                'tls.verify': 'TLSVerify', 'tls.verify_and_map': 'TLSMap',
                'compression.mode': 'Compression.Mode',
                'compression.rtt_thresholds': 'Compression.RTTThresholds'}

# calls that stand in for a value: what they resolve to, and what the report must still say
CALL_HINTS = {'getDefaultAuthTimeout': ('AUTH_TIMEOUT', 'sec', 'without TLS; with TLS configured '
                                        'it is `tls_timeout + 1`, see `getDefaultAuthTimeout()`')}

UNITS = {'time.Nanosecond': 1, 'time.Microsecond': 1e3, 'time.Millisecond': 1e6,
         'time.Second': 1e9, 'time.Minute': 6e10, 'time.Hour': 3.6e12}
SIZES = {'k': 1024, 'kb': 1024, 'kib': 1024, 'm': 1024 ** 2, 'mb': 1024 ** 2, 'mib': 1024 ** 2,
         'g': 1024 ** 3, 'gb': 1024 ** 3, 'gib': 1024 ** 3, 't': 1024 ** 4, 'tb': 1024 ** 4}
DUR = {'ns': 1, 'us': 1e3, 'µs': 1e3, 'ms': 1e6, 's': 1e9, 'm': 6e10, 'h': 3.6e12}
CASTS = re.compile(r'\b(?:int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|'
                   r'float32|float64|time\.Duration|byte|rune)\(')
ZERO = r'(?:0|0\.0|nil|_EMPTY_|""|time\.Duration\(0\))'
OPTS_ROOT = r'(?:opts|o|options|s\.opts|s\.getOpts\(\)|c\.srv\.getOpts\(\))'


# --- the source ---------------------------------------------------------------------------------
def ensure_source(tag):
    """Path to server/ for `tag`, downloading and extracting the release tarball if needed."""
    src = os.path.join(CACHE, 'nats-server-' + tag.lstrip('v'), 'server')
    if os.path.isdir(src):
        return src
    os.makedirs(CACHE, exist_ok=True)
    tgz = os.path.join(CACHE, 'nats-server-%s.tar.gz' % tag)
    if not os.path.exists(tgz):
        print('fetching', TARBALL.format(tag=tag), file=sys.stderr)
        urllib.request.urlretrieve(TARBALL.format(tag=tag), tgz)
    with tarfile.open(tgz) as t:
        t.extractall(CACHE, filter='data')
    if not os.path.isdir(src):
        sys.exit('extracted tarball has no server/ at ' + src)
    return src


def strip_comment(s):
    i = s.find('//')
    while i >= 0:
        if s[:i].count('"') % 2 == 0 and s[:i].count('`') % 2 == 0:
            return s[:i].strip()
        i = s.find('//', i + 2)
    return s.strip()


# --- indexes over the source --------------------------------------------------------------------
CONST_ASSIGN = re.compile(r'^\s*([A-Za-z_]\w*)\s+(?:[\w\.\*\[\]]+\s+)?=\s*(.+)$')
FUNC = re.compile(r'^func\s+(?:\([^)]*\)\s*)?(\w+)\s*\(')
CASE = re.compile(r'^(\s*)case\s+((?:"[^"]*"\s*,?\s*)+):')
ASSIGN = re.compile(r'^\s*(?:if\s+|\}\s*else\s+if\s+)?([A-Za-z_]\w*(?:\.\w+)+)\s*=\s*([^=].*)$')
GUARD = re.compile(r'^\s*(?:\}\s*else\s+)?if\s+(?:([A-Za-z_]\w*)\s*:=\s*&?([A-Za-z_]\w*(?:\.\w+)*);\s*)?'
                   r'([A-Za-z_]\w*(?:\.\w+)+)\s*(==|<=|<)\s*' + ZERO + r'\s*\{')
LOCAL = re.compile(r'^\s*(?:if\s+)?([a-z]\w*)\s*(?::=|=)\s*[^;]*?\b' + OPTS_ROOT +
                   r'\.([A-Z]\w*(?:\.\w+)*)\b')
LOCAL_GUARD = re.compile(r'\b(\w+)\s*(?:==|<=)\s*' + ZERO + r'\s*\{')
FLAG = re.compile(r'fs\.(Bool|Int|Int64|String|Duration|Float64)Var\(&' + OPTS_ROOT +
                  r'\.([A-Za-z_]\w*(?:\.\w+)*),\s*"[^"]*",\s*([^,]+),')


LITERAL = re.compile(r'^(\s*)(?:return\s+)?&?(?:\w+\.)?([A-Z]\w*)\{\s*$')
LITFIELD = re.compile(r'^\s*([A-Z]\w*):\s*(.+?),?\s*$')


def index_source(src):
    """Seven indexes: constants, parse-time default sites, use-site defaults, flag defaults, the
    `case "<key>"` blocks of every parse function with the fields they assign, struct-literal
    defaults (`Type.Field`), the types each function names, and the whole source as one string."""
    consts, defaults, usesites, flags, cases = {}, {}, {}, {}, {}
    structs, functypes, blob, overrides = {}, {}, {}, {}
    files = [f for f in sorted(glob.glob(src + '/**/*.go', recursive=True)) if not f.endswith('_test.go')]
    for path in files:
        rel = os.path.relpath(path, src)
        lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
        blob[rel] = lines
        in_const, fn = False, ''
        for i, raw in enumerate(lines):
            line = strip_comment(raw)
            m = FUNC.match(raw)
            if m:
                fn = m.group(1)
                functypes[fn] = set(re.findall(r'\b(?:New)?([A-Z]\w*)\b', raw))
            # constants
            if re.match(r'^\s*(?:const|var)\s*\($', line):
                in_const = True
                continue
            if in_const and re.match(r'^\s*\)\s*$', line):
                in_const = False
                continue
            if in_const or line.startswith('const ') or line.startswith('var '):
                c = CONST_ASSIGN.match(re.sub(r'^(?:const|var) ', '', line))
                if c and 'iota' not in c.group(2):
                    consts.setdefault(c.group(1), (c.group(2).rstrip(','), rel, i + 1))
            # flag defaults
            f = FLAG.search(line)
            if f:
                name = re.search(r',\s*"([^"]*)",', line)
                flags.setdefault(f.group(2), []).append((f.group(3).strip(), name.group(1) if name else '', rel, i + 1))
            # struct-literal defaults: the constructor a parse function fills its config from
            lit = LITERAL.match(raw)
            if lit:
                for j in range(i + 1, min(i + 40, len(lines))):
                    body = strip_comment(lines[j])
                    if body.startswith('}'):
                        break
                    lf = LITFIELD.match(body)
                    if lf:
                        structs.setdefault((lit.group(2), lf.group(1)), (lf.group(2), rel, j + 1))
            # parse-time default sites: if <path> == <zero> { <path> = <expr> }
            g = GUARD.match(raw)
            if g:
                alias, aliased, guarded = g.group(1), g.group(2), g.group(3)
                real = aliased + guarded[len(alias):] if alias and guarded.split('.')[0] == alias else guarded
                gind = len(raw) - len(raw.lstrip())
                for j in range(i + 1, min(i + 14, len(lines))):
                    body = strip_comment(lines[j])
                    if body.startswith('}') and len(lines[j]) - len(lines[j].lstrip()) <= gind:
                        break
                    a = ASSIGN.match(body)
                    if not a:
                        continue
                    lhs = a.group(1)
                    if alias and lhs.split('.')[0] == alias:
                        lhs = aliased + lhs[len(alias):]
                    if lhs == real:
                        defaults.setdefault(lhs, []).append((a.group(2).strip(), rel, j + 1))
            # use-site defaults: local := opts.Field ... if local == 0 { local = DEFAULT }
            u = LOCAL.match(line)
            if u:
                local, field = u.group(1), u.group(2)
                for j in range(i, min(i + 6, len(lines))):
                    seg = strip_comment(lines[j])
                    lg = LOCAL_GUARD.search(seg)
                    if not (lg and lg.group(1) == local):
                        continue
                    for k in range(j + 1, min(j + 5, len(lines))):
                        body = strip_comment(lines[k])
                        if body.startswith('}'):
                            break
                        a = re.match(r'^(\w+)\s*=\s*([^=].*)$', body)
                        if a and a.group(1) == local:
                            usesites.setdefault(field, []).append((a.group(2).strip(), rel, k + 1))
                    break
            # override defaults: `local := <the default>` … `if opts.X > 0 { local = opts.X }`
            ov = re.match(r'^\s*(?:if|case)[^{:]*\b' + OPTS_ROOT + r'\.([A-Z]\w*(?:\.\w+)*)\s*'
                          r'(?:>|!=)\s*0\s*[{:]', line)
            if ov:
                fieldp = ov.group(1)
                for j in range(i + 1, min(i + 4, len(lines))):
                    a = re.match(r'^([\w.]+)\s*=\s*[\w.()]*\.' + re.escape(fieldp) + r'$',
                                 strip_comment(lines[j]))
                    if not a:
                        continue
                    back = [(strip_comment(lines[k]), k) for k in range(max(0, i - 30), i)]
                    init = [(m.group(1).strip(), k) for t, k in back
                            for m in [re.match(r'^' + re.escape(a.group(1)) + r'\s*:?=\s*(.+)$', t)]
                            if m and fieldp not in m.group(1)]
                    for expr, k in reversed(init):       # closest initialiser first
                        overrides.setdefault(fieldp, []).append((expr, rel, k + 1))
                    break
            # case "<key>": ... and what it assigns
            c = CASE.match(raw)
            if c:
                keys, indent = re.findall(r'"([^"]*)"', c.group(2)), len(c.group(1))
                for k in keys:
                    cases.setdefault((fn, k), [])
                for j in range(i + 1, len(lines)):
                    nxt = lines[j]
                    if nxt.strip() and len(nxt) - len(nxt.lstrip()) <= indent and \
                       re.match(r'^\s*(case\s|default:|\})', nxt):
                        break
                    a = ASSIGN.match(strip_comment(nxt))
                    if a and not a.group(1).startswith('err'):
                        for k in keys:
                            cases[(fn, k)].append((a.group(1), a.group(2).strip(), rel, j + 1))
    return consts, defaults, usesites, flags, cases, structs, functypes, blob, overrides


# --- evaluating a Go constant expression ----------------------------------------------------------
class Unresolved(Exception):
    pass


def evaluate(expr, consts, seen=()):
    """(value, unit) for a Go constant expression. `unit` is 'ns' for a duration, 'sec' for a
    duration already divided into seconds, None for a plain number, string or bool."""
    expr = strip_comment(expr).strip().rstrip(',')
    if expr in ('true', 'false'):
        return expr == 'true', None
    if re.fullmatch(r'"[^"]*"', expr):
        return expr[1:-1], None
    if expr == '_EMPTY_':
        return '', None
    unit = 'ns' if re.search(r'\btime\.(Nanosecond|Microsecond|Millisecond|Second|Minute|Hour)\b', expr) else None
    if re.search(r'/\s*(float64\(\s*)?time\.Second', expr) or expr.endswith('.Seconds()'):
        unit = 'sec'
    py = expr[:-len('.Seconds()')] if expr.endswith('.Seconds()') else expr
    py = CASTS.sub('(', py)
    for name, ns in UNITS.items():
        py = py.replace(name, repr(ns))
    for ident in sorted(set(re.findall(r'\b[A-Za-z_]\w*\b', py)), key=len, reverse=True):
        if ident in ('true', 'false'):
            continue
        if ident not in consts:
            raise Unresolved('`%s` is not a constant' % expr)
        if ident in seen:
            raise Unresolved('circular constant %s' % ident)
        sub, sunit = evaluate(consts[ident][0], consts, seen + (ident,))
        if isinstance(sub, (str, bool)):
            if py.strip() == ident:
                return sub, sunit
            raise Unresolved('`%s` mixes a string constant into an expression' % expr)
        if sunit == 'ns' and unit is None:
            unit = 'ns'
        py = re.sub(r'\b%s\b' % re.escape(ident), '(' + repr(sub) + ')', py)
    try:
        tree = ast.parse(py, mode='eval')
    except SyntaxError:
        raise Unresolved('`%s` is not an arithmetic expression' % expr)
    for node in ast.walk(tree):
        if not isinstance(node, (ast.Expression, ast.BinOp, ast.UnaryOp, ast.Constant, ast.Add,
                                 ast.Sub, ast.Mult, ast.Div, ast.FloorDiv, ast.Mod, ast.Pow,
                                 ast.LShift, ast.RShift, ast.USub, ast.UAdd, ast.BitOr, ast.BitAnd)):
            raise Unresolved('`%s` is not an arithmetic expression' % expr)
    try:
        value = eval(compile(tree, '<go>', 'eval'), {'__builtins__': {}})
        return (value / 1e9 if expr.endswith('.Seconds()') else value), unit
    except Exception as e:
        raise Unresolved('`%s`: %s' % (expr, type(e).__name__))


# --- the documented value, and comparing the two ---------------------------------------------------
def parse_documented(text):
    """(kind, value) for a default cell from the docs. kind: bool|duration|size|number|string."""
    v = text.strip().strip('`').strip()
    if v in ('true', 'false'):
        return 'bool', v == 'true'
    m = re.fullmatch(r'(\d+(?:\.\d+)?)\s*(ns|us|µs|ms|s|m|h)', v)
    if m:
        return 'duration', float(m.group(1)) * DUR[m.group(2)]
    m = re.fullmatch(r'(\d+(?:\.\d+)?)\s*([kKmMgGtT][iI]?[bB]?)', v)
    if m:
        return 'size', float(m.group(1)) * SIZES[m.group(2).lower()]
    if re.fullmatch(r'-?\d+(\.\d+)?', v):
        return 'number', float(v)
    return 'string', v


def compare(doc, server, unit):
    """('agrees'|'disagrees'|'unresolved', note) — unresolved when the two are not comparable."""
    dkind, dval = doc
    if isinstance(server, bool) or dkind == 'bool':
        if isinstance(server, bool) and dkind == 'bool':
            return ('agrees' if server == dval else 'disagrees'), ''
        return 'unresolved', 'a boolean on one side only (server: `%s`)' % server
    if isinstance(server, str) or dkind == 'string':
        if isinstance(server, str) and dkind == 'string':
            return ('agrees' if server == dval else 'disagrees'), ''
        return 'unresolved', 'a string on one side only (server: `%s`)' % server
    if unit == 'sec':                       # the server keeps seconds as a float
        sns, dns = server * 1e9, (dval * 1e9 if dkind == 'number' else dval)
        if dkind not in ('number', 'duration'):
            return 'unresolved', 'server value is a duration in seconds, docs state `%s`' % dval
        return ('agrees' if abs(sns - dns) < 1 else 'disagrees'), \
               ('docs read as %s' % fmt_dur(dns) if dkind == 'number' else '')
    if unit == 'ns':
        if dkind == 'duration':
            return ('agrees' if abs(server - dval) < 1 else 'disagrees'), ''
        return 'unresolved', 'server value is a duration (%s), docs state `%s`' % (fmt_dur(server), dval)
    if dkind in ('number', 'size'):
        if dval == 0 and server < 0:
            return 'agrees', 'the docs\' `0` is stored as `%d` (no limit)' % server
        return ('agrees' if abs(float(server) - dval) < 1e-9 else 'disagrees'), ''
    return 'unresolved', 'not comparable'


def fmt_dur(ns):
    for suffix, mult in (('h', 3.6e12), ('m', 6e10), ('s', 1e9), ('ms', 1e6), ('us', 1e3)):
        if ns >= mult and abs(ns / mult - round(ns / mult)) < 1e-9:
            return '%g%s' % (ns / mult, suffix)
    return '%gns' % ns


def fmt_server(value, unit, dkind):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return value or '(empty)'
    if unit == 'ns':
        return fmt_dur(value)
    if unit == 'sec':
        return '%g (%s)' % (value, fmt_dur(value * 1e9))
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    if dkind == 'size' and isinstance(value, int) and value >= 1024:
        for suffix, mult in (('TB', 1024 ** 4), ('GB', 1024 ** 3), ('MB', 1024 ** 2), ('KB', 1024)):
            if value >= mult and value % mult == 0:
                return '%d (%d%s)' % (value, value // mult, suffix)
    return str(value)


# --- resolving one documented key -------------------------------------------------------------------
def grep(blob, pattern):
    """[(file, line number, text)] for every line matching `pattern`."""
    rx = re.compile(pattern)
    return [(f, i + 1, l) for f, lines in blob.items() for i, l in enumerate(lines) if rx.search(l)]


def block_for(prefix):
    """(parse function, Options field path, roots, family) for a documented key prefix."""
    if prefix in BLOCKS:
        fn, field, roots = BLOCKS[prefix]
        return fn, field, roots, None
    for family, fn in FAMILIES:
        if prefix == family or prefix.endswith('.' + family):
            owner = prefix[:-len(family)].rstrip('.')
            ofield, oroots = BLOCKS.get(owner, (None, None, ('o', 'opts')))[1:]
            return fn, ofield, oroots, family
    return None, None, None, None


def sites_for(index, field, roots):
    """Default sites for `field`, written through one of `roots`. Exact path first."""
    exact = [(p, e, f, l) for p, sites in index.items() for e, f, l in sites
             if p.split('.', 1)[0] in roots and p.split('.', 1)[-1] == field]
    if exact:
        return exact
    return [(p, e, f, l) for p, sites in index.items() for e, f, l in sites
            if p.split('.', 1)[0] in roots and p.split('.', 1)[-1].endswith('.' + field)]


def pick(hits, consts, kind):
    """One (value, unit, where, note) from candidate sites, or raise with what was found."""
    vals = {}
    for p, e, f, l in hits:
        try:
            vals[evaluate(e, consts)] = (e, f, l)
        except Unresolved:
            continue                                     # a test hook, a call, a runtime value
    if len(vals) == 1:
        (value, unit), (e, f, l) = next(iter(vals.items()))
        note = '%d %s sites, %d resolvable' % (len(hits), kind, len(vals)) if len(hits) > 1 else ''
        return value, unit, '%s:%d' % (f, l), note
    if len(vals) > 1:
        raise Unresolved('%d different %s sites: %s' %
                         (len(vals), kind, ', '.join(sorted('`%s`' % v[0] for v in vals.values()))))
    raise Unresolved('%s site %s:%d sets it to %s' % (kind, hits[0][2], hits[0][3],
                                                      '`%s`' % hits[0][1]))


def value_of(hits, consts, kind):
    """(value, unit, where, note) from candidate sites, following a call hint if one applies."""
    try:
        return pick(hits, consts, kind)
    except Unresolved:
        for _p, expr, f, l in hits:
            call = re.match(r'(\w+)\(', expr)
            if call and call.group(1) in CALL_HINTS:
                cname, cunit, cnote = CALL_HINTS[call.group(1)]
                v, u = evaluate(consts[cname][0], consts)
                return (v / 1e9 if cunit == 'sec' and u == 'ns' else v), cunit, '%s:%d' % (f, l), \
                       '`%s`, %s' % (cname, cnote)
        raise


def default_of(path, defaults, consts):
    """(value, unit, where, note) for an option referred to by path, e.g. `opts.AuthTimeout`."""
    sub = sites_for(defaults, path.split('.', 1)[-1], (path.split('.')[0],))
    if not sub:
        raise Unresolved('nothing defaults `%s`' % path)
    return value_of(sub, consts, 'default')


def resolve(key, idx):
    """(value, unit, via, where, note) or raise Unresolved. `idx` is what index_source returned."""
    consts, defaults, usesites, flags, cases, structs, functypes, blob, overrides = idx
    prefix, _, leaf = key.rpartition('.')
    fn, ofield, roots, family = block_for(prefix)
    if not fn:
        raise Unresolved('no parse function known for the `%s` block' % (prefix or '(top level)'))
    if (fn, leaf) not in cases:
        raise Unresolved('no `case "%s"` in `%s()`' % (leaf, fn))
    assigned = [a for a in cases[(fn, leaf)]
                if not re.fullmatch(r'true|false|[A-Z]\w*|[A-Za-z_]\w*\.[A-Z]\w*', a[1])]
    field, on_options, rhs = None, False, ''
    for path, expr, _f, _l in assigned:                  # prefer an Options field over a local
        if path.split('.')[0] in ('o', 'opts', 'options'):
            field, on_options, rhs = path.split('.', 1)[1], True, expr
            break
    if field is None:
        hint = FAMILY_FIELD.get('%s.%s' % (family, leaf)) if family else None
        if hint:
            field = (ofield + '.' + hint).lstrip('.') if ofield else hint
            on_options = ofield is not None
        elif assigned:
            field, rhs = assigned[0][0].split('.', 1)[1], assigned[0][1]   # a local struct
        else:
            raise Unresolved('`case "%s"` in `%s()` assigns nothing (handled elsewhere)' % (leaf, fn))
    first = None
    # 1. the option parser fills the option in
    hits = sites_for(defaults, field, roots)
    if hits:
        try:
            value, unit, where, note = value_of(hits, consts, 'default')
            return value, unit, 'assign', where, note
        except Unresolved as e:
            first = e
            transitive = [h for h in hits if re.fullmatch(r'[A-Za-z_]\w*(\.\w+)+', h[1])]
            if len(transitive) == 1:                     # a default that is another option
                other = transitive[0][1]
                try:
                    v, u, w, _n = default_of(other, defaults, consts)
                    return v, u, 'assign', w, 'via `%s`, defaulted at %s' % (other, w)
                except Unresolved:
                    pass
    # 2. the parse function fills its config struct from a constructor
    for typ in sorted(functypes.get(fn, ())):
        lit = structs.get((typ, field.split('.')[-1]))
        if not lit:
            continue
        try:
            value, unit = evaluate(lit[0], consts)
        except Unresolved:
            continue
        return value, unit, 'literal', '%s:%d' % (lit[1], lit[2]), '`%s{%s}`' % (typ, field.split('.')[-1])
    # 3. the option is defaulted where it is read
    hits = sites_for(usesites, field, roots) or [(field, e, f, l) for e, f, l in usesites.get(field, [])]
    if hits:
        try:
            value, unit, where, note = pick(hits, consts, 'use')
            return value, unit, 'use-site', where, note
        except Unresolved:
            pass
    # 3b. `x := <default>` … `if opts.<field> > 0 { x = opts.<field> }` — the initial value is it
    for expr, f, l in overrides.get(field, ()):          # closest initialiser first
        try:
            value, unit = evaluate(expr, consts)
            return value, unit, 'use-site', '%s:%d' % (f, l), 'the value used unless the key is set'
        except Unresolved:
            pass
        if re.fullmatch(r'[A-Za-z_]\w*(\.\w+)+', expr):
            try:
                v, u, w, note = default_of(expr, defaults, consts)
                return v, u, 'global', w, 'no default of its own; the key only overrides `%s`%s' \
                       % (expr, ('; ' + note) if note else '')
            except Unresolved:
                pass
    # 4. the command-line flag registers a default for the same field, under the same name
    for expr, name, f, l in flags.get(field, ()):
        if name not in (leaf, key):
            continue
        try:
            value, unit = evaluate(expr, consts)
        except Unresolved:
            break
        if value not in (0, False, ''):                  # a zero flag value is the "unset" marker
            return value, unit, 'flag-default', '%s:%d' % (f, l), 'the `-%s` flag' % name
    # 6. a constant named after the field, or after the block and the key
    wants = [field.replace('.', '')] + ([prefix.split('.')[-1] + leaf] if prefix else [leaf])
    for want in wants:
        norm = re.sub(r'[^a-z]', '', want.lower())
        for name, (expr, f, l) in sorted(consts.items()):
            if 'default' not in name.lower():
                continue
            if re.sub(r'[^a-z]', '', name.lower()).replace('default', '') != norm:
                continue
            try:
                value, unit = evaluate(expr, consts)
            except Unresolved:
                continue
            return value, unit, 'const-name', '%s:%d' % (f, l), 'the constant `%s`' % name
    if first:
        raise first
    if on_options and (rhs.startswith('&') or 'New' in rhs or '{' in rhs):
        raise Unresolved('`%s` is filled from `%s`, not a scalar the resolver can compare' % (field, rhs))
    if on_options and rhs.startswith('!'):
        raise Unresolved('the option is the negation of the key (`%s = %s`)' % (field, rhs))
    if on_options:
        if not grep(blob, r'\.%s\b' % re.escape(field.split('.')[-1])):
            raise Unresolved('there is no `Options.%s` in the source — this key may not reach an '
                             'option at all' % field)
        elsewhere = [(p, e, f, l) for p, sites in list(defaults.items()) + list(usesites.items())
                     for e, f, l in sites if p.split('.', 1)[-1] == field.split('.')[-1]]
        if elsewhere:
            raise Unresolved('`%s` is filled nowhere; the nearest default sites are under another '
                             'root: %s' % (field, ', '.join(sorted('`%s` (%s:%d)' % (p, f, l)
                                                                   for p, _e, f, l in elsewhere))[:200]))
        last = field.split('.')[-1]
        read = [g for g in grep(blob, r'\.%s\s*(?:>|!=|==|<=)\s*0\b' % re.escape(last))
                if not g[0].startswith('opts.go')]
        if read:
            raise Unresolved('`%s` is filled nowhere but compared with zero at %s — the default '
                             'is applied there' % (field, ', '.join('`%s:%d`' % (f, n)
                                                                            for f, n, _t in read[:3])))
        # the parser reads the key into an Options field that nothing ever fills in
        raise Unresolved('nothing fills `%s` in: no default site, no use site, no flag and no '
                         'constant named after it, so Go\'s zero value stands' % field)
    raise Unresolved('no default site, no flag and no constant named after `%s`' % field)


SRC = ''


def main():
    global SRC
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--tag', default='v2.14.6')
    ap.add_argument('--src', help='an existing server/ directory; skips the download')
    ap.add_argument('--table', default=TABLE)
    ap.add_argument('--only', default='', help='only keys starting with this prefix')
    ap.add_argument('--explain', help='resolve one key and print the evidence')
    ap.add_argument('--out', help='report path (default inbox/check-defaults-<tag>.md)')
    a = ap.parse_args()
    SRC = a.src or ensure_source(a.tag)
    idx = index_source(SRC)
    rows = []
    for line in open(a.table, encoding='utf-8'):
        if not line.startswith('|'):
            continue
        c = [x.strip() for x in line.strip().strip('|').split('|')]
        if len(c) < 6 or c[0] == 'key' or set(c[0]) <= set('-: '):
            continue
        rows.append(c)
    if a.explain:
        c = next((c for c in rows if c[0] == a.explain), None)
        if not c:
            sys.exit('no such key in ' + a.table)
        print('key      ', c[0])
        print('docs     ', c[2] or '(none stated)')
        try:
            value, unit, via, where, note = resolve(c[0], idx)
            print('server   ', fmt_server(value, unit, parse_documented(c[2])[0] if c[2] else ''))
            print('via      ', via, '·', where, ('· ' + note) if note else '')
            print('verdict  ', compare(parse_documented(c[2]), value, unit)[0] if c[2] else 'n/a')
        except Unresolved as e:
            print('server    unresolved:', e)
        return
    documented = [c for c in rows if c[2] not in ('', '-') and c[0].startswith(a.only)]
    out = {'disagrees': [], 'agrees': [], 'unresolved': []}
    for c in documented:
        key, dflt = c[0], c[2]
        doc = parse_documented(dflt)
        try:
            value, unit, via, where, note = resolve(key, idx)
        except Unresolved as e:
            zero = str(e).startswith('nothing fills `') and doc[0] in ('bool', 'number')
            if doc[0] == 'bool' and doc[1] is False or doc[0] == 'number' and doc[1] == 0:
                out['agrees'].append((key, dflt, dflt.strip('`'), 'zero-value', '', str(e)))
            elif zero:
                out['disagrees'].append((key, dflt, 'unset', 'zero-value', '', str(e)))
            else:
                out['unresolved'].append((key, dflt, '', '', '', str(e)))
            continue
        verdict, note2 = compare(doc, value, unit)
        out[verdict].append((key, dflt, fmt_server(value, unit, doc[0]), via, where,
                             '; '.join(x for x in (note, note2) if x)))
    path = a.out or os.path.join(ROOT, 'inbox', 'check-defaults-%s.md' % a.tag)
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(report(a.tag, len(documented), len(rows), out))
    for k in ('disagrees', 'unresolved', 'agrees'):
        print('%-11s %3d' % (k, len(out[k])))
    print('checked %d documented defaults of %d keys · report: %s'
          % (len(documented), len(rows), os.path.relpath(path, ROOT)))


def report(tag, n, total, out):
    """One table, one row per documented default, so the viewer can filter it by verdict."""
    order = {'disagrees': 0, 'unresolved': 1, 'agrees': 2}
    rows = sorted(((v, r) for v, rs in out.items() for r in rs), key=lambda x: (order[x[0]], x[1][0]))
    body = '| key | verdict | docs | server | via | where | note |\n|---|---|---|---|---|---|---|\n'
    for verdict, (key, dflt, server, via, where, note) in rows:
        link = ''
        if where:
            f, _, l = where.partition(':')
            link = '[`%s`](%s)' % (where, BLOB.format(tag=tag, file=f, line=l))
        mark = {'disagrees': '★ disagrees', 'unresolved': 'unresolved', 'agrees': 'agrees'}[verdict]
        body += '| `%s` | %s | `%s` | %s | %s | %s | %s |\n' % (
            key, mark, dflt.strip('`'), ('`%s`' % server) if server else '', via, link, note)
    counts = {k: len(v) for k, v in out.items()}
    by_via = {}
    for k in ('agrees', 'disagrees'):
        for row in out[k]:
            by_via[row[3]] = by_via.get(row[3], 0) + 1
    return f"""# Config defaults — docs vs nats-server {tag}

Generated by `tools/check-defaults.py` from `inbox/config-keys-table.md` and the `nats-server` source
at **{tag}**. Of {total} documented keys, **{n} state a default**; each is resolved against the code that
fills the option in. One row per documented default, most alarming first:
**{counts['disagrees']} disagree**, {counts['unresolved']} could not be resolved mechanically, {counts['agrees']} agree.

**This file is a worklist, not evidence.** A `★ disagrees` row is a suspicion until someone has read
the source at the linked line — `CLAUDE.md` → *Operation: record a docs issue* wants the constant
quoted with its file and line, and the behaviour run on the binary, before anything becomes a row in
`inbox/docs-issues.md`. Re-run after a release and diff this file.

The `via` column says how the value was found. They are not equally strong, strongest first
(this page carries **one table**, so the viewer can filter it — hence a list, not a second one):

- **`assign`** — a guarded default site in the option parser, `if opts.X == 0 {{ opts.X = DEFAULT_X }}`.
  The server filling in an unset option.
- **`use-site`** — the option is read into a local and defaulted there. Just as real, but the value
  never reaches the Options struct, so `/varz` will not show it.
- **`global`** — the block has no default of its own; the key only overrides a top-level one. The
  documented value can be right and the *mechanism* still be worth stating.
- **`flag-default`** — the value the command-line flag registers for the same field.
- **`literal`** — the constructor the parse function fills its config struct from.
- **`const-name`** — no site found, but a constant is merely *named* after the field. Read the use
  site before believing it.
- **`zero-value`** — nothing sets it, so Go's zero value stands: a presumption, not a reading.

Resolved by: {', '.join('%s %d' % (v, c) for v, c in sorted(by_via.items(), key=lambda x: -x[1]))}.

An `unresolved` row is the honest output, not a failure: the resolver walks from the parse function
that reads the key to the code that fills the field in, and these keys defeat it — the value is
computed at run time, lives on a struct it cannot name, is not a constant, or the key is handled
somewhere other than its own `case`. The note says what was found and where to look.

{body}"""


if __name__ == '__main__':
    main()
