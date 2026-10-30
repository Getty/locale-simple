from gettext import textdomain, dngettext, ngettext, bindtextdomain, dgettext, gettext
try:
    from gettext import bind_textdomain_codeset
except ImportError:
    bind_textdomain_codeset = None
import os, sys, re

__version__ = "0.109"

__all__ = [
    'l_nolocales',
    'l_dry',
    'l_dir',
    'l_lang',
    'ltd',
    'l',
    'ln',
    'lp',
    'lnp',
    'ld',
    'ldn',
    'ldp',
    'ldnp',
    'N_',
    'Nn_',
    'Np_',
    'Nnp_',
    'Nd_',
    'Ndn_',
    'Ndp_',
    'Ndnp_',
]

global dry, nowrite, nolocales, dir 
dry, nowrite, nolocales, dir = None, None, None, None
tds = {}

def l_nolocales(x):
    global nolocales
    nolocales = x
def l_dry(d, n=False):
    global dry, nowrite, nolocales
    dry, nowrite, nolocales = d, n, bool(d)
def l_dir(d): 
    global dir
    if not os.path.isdir(d): raise OSError("%s: No such file or directory" % d)
    dir = d
    for td in list(tds):
        _bind(td)

# Binds a text domain to the l_dir() directory. ltd(), the ld* helpers and
# l_dir() all bind through here, so every bound domain follows l_dir().
def _bind(td):
    bindtextdomain(td, dir)
    if bind_textdomain_codeset:
        bind_textdomain_codeset(td, 'utf-8')
    tds[td] = 1

def _die(msg):
    sys.stderr.write(msg + '\n')
    exit(1)

def _check_dir():
    if not dir and not nolocales:
        _die("please set a locale directory with l_dir() before using other translate functions")

def gettext_escape(content):
    content = content.replace('\\', '\\\\')
    content = content.replace('\n', '\\n')
    content = content.replace('\t', '\\t')
    content = content.replace('\r', '\\r')
    content = content.replace('"', '\\"')
    return content

def l_lang(primary):
    for var in 'LANG', 'LANGUAGE', 'LC_ALL':
        os.environ.update({var: primary})

def wd(data):
    if nowrite: return
    with open(dry, 'a', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(data) + "\n\n")

_PLACEHOLDER = re.compile(
    r'%%|%(?:(\d+)\$)?([-+ 0#]*)(\*|\d+)?(?:\.(\*|\d+))?([scoxXuidfFeEgG])'
)

# One pass over the format: the text between placeholders is copied, and each
# placeholder is formatted on its own with its own argument, so an argument
# value is never read as a format. %2$s picks its argument, a placeholder
# without N$ takes the next one in order (a * width or precision too), as in
# Perl. A placeholder without an argument stays as it is; extra arguments are
# ignored.
def sprintf(string, *args):
    out = []
    last = 0
    implicit = 0
    for m in _PLACEHOLDER.finditer(string):
        out.append(string[last:m.start()])
        last = m.end()
        if m.group(0) == '%%':
            out.append('%')
            continue
        index, flags, width, precision, conversion = m.groups()
        picks = []
        for star in (width, precision):
            if star == '*':
                picks.append(implicit)
                implicit += 1
        if index:
            picks.append(int(index) - 1)
        else:
            picks.append(implicit)
            implicit += 1
        if not all(0 <= i < len(args) for i in picks):
            out.append(m.group(0))
            continue
        spec = '%' + flags + (width or '')
        if precision is not None:
            spec += '.' + precision
        out.append((spec + conversion) % tuple(args[i] for i in picks))
    out.append(string[last:])
    return ''.join(out)

def l(id, *args):
    return ldnp('', None, id, None, None, *args)
def ln(id, idp, n, *args):
    return ldnp('', None, id, idp, n, *args)
def lp(ctxt, id, *args):
    return ldnp('', ctxt, id, None, None, *args)
def lnp(ctxt, id, idp, n, *args):
    return ldnp('', ctxt, id, idp, n, *args)
def ld(td, id, *args):
    return ldnp(td, None, id, None, None, *args)
def ldn(td, id, idp, n, *args):
    return ldnp(td, None, id, idp, n, *args)
def ldp(td, ctxt, id, *args):
    return ldnp(td, ctxt, id, None, None, *args)

def ldnp(td, ctxt, id, idp, n, *args):
    if not len(id): return id
    _check_dir()

    if idp is not None: args = (n,) + args
    is_plural = idp is not None
    out = None
    if dry:
        if not nowrite:
            save = []
            if td: save.append('# domain: '+td)
            if ctxt: save.append('msgctxt "'+gettext_escape(ctxt)+'"')
            save.append('msgid "'+gettext_escape(id)+'"')
            if idp: save.append('msgid_plural "'+gettext_escape(idp)+'"')
            wd(save)
        out = sprintf(idp if is_plural and n != 1 else id, *args)
    else:
        if td and td not in tds: _bind(td)
        key = (ctxt + '\x04' + id) if ctxt else id
        keyp = (ctxt + '\x04' + idp) if ctxt and idp else idp
        if   td and is_plural:     raw = dngettext(td, key, keyp, n)
        elif td and not is_plural: raw = dgettext(td, key)
        elif is_plural:            raw = ngettext(key, keyp, n)
        else:                      raw = gettext(key)

        # gettext returns the input string untouched when no translation
        # exists, so for a pgettext-style lookup we have to strip the
        # "ctxt\x04" prefix ourselves to fall back to the plain msgid.
        if ctxt and raw.startswith(ctxt + '\x04'):
            raw = raw[len(ctxt) + 1:]

        out = sprintf(raw, *args)
    return out

# Deferred-translation markers — runtime no-ops so strings can be declared
# before a user locale is known (class-construction time, DSLs, constants)
# and still show up in the extracted .pot. Pass the stored msgid(s) through
# the real l*() at render time. See Locale::Simple POD for the full story.
def N_(msgid):
    return msgid
def Nn_(sg, pl):
    return (sg, pl)
def Np_(ctxt, msgid):
    return msgid
def Nnp_(ctxt, sg, pl):
    return (sg, pl)
def Nd_(td, msgid):
    return msgid
def Ndn_(td, sg, pl):
    return (sg, pl)
def Ndp_(td, ctxt, msgid):
    return msgid
def Ndnp_(td, ctxt, sg, pl):
    return (sg, pl)


def ltd(td):
    _check_dir()
    if td not in tds: _bind(td)
    textdomain(td)
