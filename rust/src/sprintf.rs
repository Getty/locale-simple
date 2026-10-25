//! sprintf with the conversions of the shared spec (§5): `b c d e u f F o s x X`,
//! flags `+ - 0 space '<char>`, width, `.precision`, the `N$` position and `%%`.
//! A placeholder without a matching argument stays in the output unchanged;
//! surplus arguments are ignored. `format!` cannot do this: its format string
//! is fixed at compile time, and these come from a `.mo` file.

use std::fmt::Display;

pub fn sprintf(format: &str, args: &[&dyn Display]) -> String {
    if !format.contains('%') {
        return format.to_string();
    }
    let mut out = String::with_capacity(format.len());
    let mut next = 0;
    let mut rest = format;
    while let Some(p) = rest.find('%') {
        out.push_str(&rest[..p]);
        rest = &rest[p..];
        match parse_spec(rest) {
            None => {
                out.push('%');
                rest = &rest[1..];
            }
            Some((Spec { verb: '%', .. }, size)) => {
                out.push('%');
                rest = &rest[size..];
            }
            Some((spec, size)) => {
                let idx = match spec.pos {
                    Some(p) => p - 1,
                    None => {
                        next += 1;
                        next - 1
                    }
                };
                match args.get(idx) {
                    Some(arg) => out.push_str(&spec.render(&arg.to_string())),
                    None => out.push_str(&rest[..size]),
                }
                rest = &rest[size..];
            }
        }
    }
    out.push_str(rest);
    out
}

struct Spec {
    pos: Option<usize>,
    plus: bool,
    left: bool,
    zero: bool,
    space: bool,
    pad: char,
    width: usize,
    precision: Option<usize>,
    verb: char,
}

/// Reads one conversion at the start of `s` (which begins with `%`).
fn parse_spec(s: &str) -> Option<(Spec, usize)> {
    let b = s.as_bytes();
    let mut sp = Spec {
        pos: None,
        plus: false,
        left: false,
        zero: false,
        space: false,
        pad: ' ',
        width: 0,
        precision: None,
        verb: ' ',
    };
    if b.get(1) == Some(&b'%') {
        sp.verb = '%';
        return Some((sp, 2));
    }
    let mut i = 1;
    let digits = |from: usize| b[from..].iter().take_while(|c| c.is_ascii_digit()).count();
    let d = digits(i);
    if d > 0 && b.get(i + d) == Some(&b'$') {
        let p: usize = s[i..i + d].parse().ok()?;
        if p == 0 {
            return None;
        }
        sp.pos = Some(p);
        i += d + 1;
    }
    loop {
        match b.get(i) {
            Some(b'+') => sp.plus = true,
            Some(b'-') => sp.left = true,
            Some(b'0') => sp.zero = true,
            Some(b' ') => sp.space = true,
            Some(b'\'') => {
                let c = s[i + 1..].chars().next()?;
                sp.pad = c;
                i += c.len_utf8();
            }
            _ => break,
        }
        i += 1;
    }
    let d = digits(i);
    if d > 0 {
        sp.width = s[i..i + d].parse().ok()?;
        i += d;
    }
    if b.get(i) == Some(&b'.') {
        let d = digits(i + 1);
        sp.precision = Some(s[i + 1..i + 1 + d].parse().unwrap_or(0));
        i += 1 + d;
    }
    let verb = *b.get(i)? as char;
    if !"bcdeufFosxX".contains(verb) {
        return None;
    }
    sp.verb = verb;
    Some((sp, i + 1))
}

fn to_int(s: &str) -> i64 {
    let s = s.trim();
    s.parse::<i64>()
        .or_else(|_| s.parse::<f64>().map(|f| f as i64))
        .unwrap_or(0)
}

fn to_float(s: &str) -> f64 {
    s.trim().parse::<f64>().unwrap_or(0.0)
}

/// C-style exponent: `1.5e+03`, at least two digits.
fn exponent(v: f64, prec: usize) -> String {
    let s = format!("{:.*e}", prec, v);
    match s.split_once('e') {
        Some((m, e)) => {
            let exp: i32 = e.parse().unwrap_or(0);
            format!("{}e{}{:02}", m, if exp < 0 { '-' } else { '+' }, exp.abs())
        }
        None => s,
    }
}

impl Spec {
    fn sign(&self) -> &'static str {
        if self.plus {
            "+"
        } else if self.space {
            " "
        } else {
            ""
        }
    }

    fn render(&self, arg: &str) -> String {
        let mut sign = "";
        let mut numeric = true;
        let body = match self.verb {
            's' => {
                numeric = false;
                match self.precision {
                    Some(p) => arg.chars().take(p).collect(),
                    None => arg.to_string(),
                }
            }
            'c' => {
                numeric = false;
                char::from_u32(to_int(arg) as u32)
                    .map(String::from)
                    .unwrap_or_default()
            }
            'd' => {
                let v = to_int(arg);
                sign = if v < 0 { "-" } else { self.sign() };
                v.unsigned_abs().to_string()
            }
            'u' => (to_int(arg) as u64).to_string(),
            'b' => format!("{:b}", to_int(arg) as u64),
            'o' => format!("{:o}", to_int(arg) as u64),
            'x' => format!("{:x}", to_int(arg) as u64),
            'X' => format!("{:X}", to_int(arg) as u64),
            _ => {
                let v = to_float(arg);
                let prec = self.precision.unwrap_or(6);
                let s = if self.verb == 'e' {
                    exponent(v.abs(), prec)
                } else {
                    format!("{:.*}", prec, v.abs())
                };
                sign = if v.is_sign_negative() && v != 0.0 {
                    "-"
                } else {
                    self.sign()
                };
                s
            }
        };
        self.justify(sign, &body, numeric)
    }

    fn justify(&self, sign: &str, body: &str, numeric: bool) -> String {
        let used = sign.chars().count() + body.chars().count();
        if self.width <= used {
            return format!("{}{}", sign, body);
        }
        let fill = self.width - used;
        if self.left {
            format!("{}{}{}", sign, body, self.pad.to_string().repeat(fill))
        } else if self.zero && numeric && self.pad == ' ' {
            format!("{}{}{}", sign, "0".repeat(fill), body)
        } else {
            format!("{}{}{}", self.pad.to_string().repeat(fill), sign, body)
        }
    }
}
