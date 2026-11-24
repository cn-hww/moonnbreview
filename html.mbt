///|
priv struct HtmlWriter {
  buffer : StringBuilder
  mut size : Int32
}

///|
fn HtmlWriter::write(
  self : HtmlWriter,
  text : String,
) -> Unit raise ReviewError {
  guard text.length() <= 16000000 - self.size else {
    raise Invalid(
      "HTML exceeds 16000000 UTF-16 units; use the complete JSON report",
    )
  }
  self.buffer.write_string(text)
  self.size += text.length()
}

///|
// Dynamic content is written only in element text, never markup/attributes.
// Escape once per scalar; even strings containing entity-looking text stay literal.
fn HtmlWriter::text(self : HtmlWriter, text : String) -> Unit raise ReviewError {
  for char in text {
    match char {
      '&' => self.write("&amp;")
      '<' => self.write("&lt;")
      '>' => self.write("&gt;")
      '"' => self.write("&quot;")
      '\'' => self.write("&#39;")
      _ => {
        let width = if char.to_int() > 0xFFFF { 2 } else { 1 }
        guard width <= 16000000 - self.size else {
          raise Invalid(
            "HTML exceeds 16000000 UTF-16 units; use the complete JSON report",
          )
        }
        self.buffer.write_char(char)
        self.size += width
      }
    }
  }
}

///|
fn HtmlWriter::pre(self : HtmlWriter, text : String) -> Unit raise ReviewError {
  self.write("<pre><code>")
  self.text(text)
  self.write("</code></pre>\n")
}

///|
fn HtmlWriter::value(
  self : HtmlWriter,
  value : Json?,
) -> Unit raise ReviewError {
  match value {
    None => self.write("<p class=absent>Absent (field not present).</p>\n")
    Some(String(text)) => self.pre(display_controls(text))
    Some(value) => self.pre(canonical(value))
  }
}

///|
fn HtmlWriter::change(
  self : HtmlWriter,
  change : Change,
  number : Int32,
) -> Unit raise ReviewError {
  let expanded = change.suppressed_by is None &&
    (change.kind == Source || change.kind == Structure)
  self.write(
    if expanded {
      "<details class=change open>\n"
    } else {
      "<details class=change>\n"
    },
  )
  self.write(
    "<summary>" +
    number.to_string() +
    ". " +
    change.kind.label() +
    "</summary>\n",
  )
  self.write("<div class=context><h3>Location and policy</h3>\n")
  self.pre(
    canonical({
      "cell_id": change.cell_id.map(Json::string).unwrap_or(Json::null()),
      "path": Json(change.path),
      "suppressed_by": change.suppressed_by
      .map(Json::string)
      .unwrap_or(Json::null()),
    }),
  )
  self.write("</div><div class=values><section><h3>Before</h3>\n")
  self.value(change.before)
  self.write("</section><section><h3>After</h3>\n")
  self.value(change.after)
  self.write("</section></div></details>\n")
}

///|
/// Complete, deterministic, self-contained HTML review. Notebook content is
/// literal text; no scripts, remote assets, images or notebook HTML are executed.
/// Full JSON evidence is included. Oversize output raises atomically at 16M
/// UTF-16 units; no payload is truncated. Report-1's 8M limit also applies.
pub fn Comparison::to_html(
  self : Comparison,
  group_mime~ : Bool = false,
) -> String raise ReviewError {
  let json = self.to_json()
  let out : HtmlWriter = { buffer: StringBuilder(), size: 0, }
  let header =
    #|<!doctype html>
    #|<html lang="en"><head><meta charset="utf-8">
    #|<meta name="viewport" content="width=device-width, initial-scale=1">
    #|<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
    #|<meta name="referrer" content="no-referrer">
    #|<title>Notebook review</title>
    #|<style>
    #|:root{color-scheme:light;font-family:system-ui,sans-serif;color:#172b3a;background:#f5f7fa}
    #|body{max-width:1100px;margin:0 auto;padding:40px 24px 64px;line-height:1.6}
    #|h1{font-size:2.1rem;letter-spacing:-.03em;margin:0}h2{margin-top:36px}h3{font-size:.9rem;color:#42566a}
    #|.counts{font-size:1.05rem}.note,.absent{color:#526477}details{background:white;border:1px solid #d4dde6;border-radius:8px;margin:12px 0}
    #|summary{padding:14px 18px;font-weight:650;cursor:pointer}summary:focus-visible{outline:3px solid #126a9d;outline-offset:2px}
    #|.context,.values{padding:0 18px 12px}.values{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:20px}
    #|pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f1f4f7;border-radius:4px;padding:12px;font-size:.86rem;tab-size:4;line-height:1.5}
    #|code{font-family:ui-monospace,Consolas,monospace}.evidence{padding:0 18px 16px}
    #|@media(max-width:700px){body{padding:24px 14px}.values{grid-template-columns:1fr;gap:0}}
    #|</style></head><body><main>
    #|<h1>Notebook review</h1>
    #|<p class="note">Offline, literal-text evidence. Expand a change to inspect both values. No notebook content is executed.</p>
  out.write(header)
  let active = self.items.filter(c => c.suppressed_by is None)
  let suppressed = self.items.filter(c => c.suppressed_by is Some(_))
  out.write(
    "<p class=counts>Active changes: " +
    active.length().to_string() +
    " &middot; Suppressed changes: " +
    suppressed.length().to_string() +
    "</p>\n",
  )
  out.write(
    "<p class=note>Change counts are evidence, not a gate verdict. Preserve the gate file and CI result separately.</p>\n",
  )
  if group_mime {
    out.write(
      "<p class=note>MIME-addressed changes are grouped by literal data key. Other evidence stays in its section. All payloads remain literal text.</p>\n",
    )
  }
  for
    (title, items) in [
      ("Active changes", active),
      ("Suppressed changes", suppressed),
    ] {
    out.write("<section><h2>" + title + "</h2>\n")
    if items.is_empty() {
      out.write("<p>None.</p>\n")
    }
    let mut ordinal = 1
    for change in items {
      if !group_mime || change.mime_key() is None {
        out.change(change, ordinal)
        ordinal += 1
      }
    }
    if group_mime {
      for group in mime_groups(items) {
        out.write("<section class=mime-group><h3>MIME data key</h3>\n")
        out.pre(group.key)
        out.write(
          "<p class=note>Media category: " +
          group.category.label() +
          ". Payload is displayed as data.</p>\n",
        )
        for change in group.changes {
          out.change(change, ordinal)
          ordinal += 1
        }
        out.write("</section>\n")
      }
    }
    out.write("</section>\n")
  }
  out.write(
    "<details><summary>Complete JSON evidence (report-1)</summary><div class=evidence>\n",
  )
  out.pre(json)
  out.write("</div></details>\n</main></body></html>\n")
  out.buffer.to_string()
}
