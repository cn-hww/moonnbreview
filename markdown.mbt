///|
priv struct MarkdownWriter {
  buffer : StringBuilder
  mut size : Int32
}

///|
fn MarkdownWriter::write(
  self : MarkdownWriter,
  text : String,
) -> Unit raise ReviewError {
  guard text.length() <= 1000000 - self.size else {
    raise Invalid(
      "Markdown exceeds 1000000 UTF-16 units; use the complete JSON report",
    )
  }
  self.buffer.write_string(text)
  self.size += text.length()
}

///|
// Choose a fence longer than every tilde run in the payload. Notebook strings,
// paths, HTML and Markdown remain literal content of a fenced code block.
fn MarkdownWriter::block(
  self : MarkdownWriter,
  text : String,
  language : String,
) -> Unit raise ReviewError {
  let safe = display_controls(text)
  let mut run = 0
  let mut longest = 0
  for char in safe {
    if char == '~' {
      run += 1
      longest = longest.max(run)
    } else {
      run = 0
    }
  }
  let fence = "~".repeat((longest + 1).max(3))
  self.write(fence + language + "\n")
  self.write(safe)
  self.write("\n" + fence + "\n\n")
}

///|
fn display_controls(text : String) -> String {
  let out = StringBuilder()
  let hex = "0123456789abcdef"
  for char in text {
    let code = char.to_int()
    if (code < 32 && char != '\n' && char != '\t') ||
      (code >= 127 && code <= 159) {
      out.write_string("\\u00")
      out.write_char(hex[code >> 4].unsafe_to_char())
      out.write_char(hex[code & 15].unsafe_to_char())
    } else {
      out.write_char(char)
    }
  }
  out.to_string()
}

///|
fn MarkdownWriter::value(
  self : MarkdownWriter,
  value : Json?,
  preview_chars : Int32,
) -> Unit raise ReviewError {
  guard value is Some(value) else {
    self.write("Absent.\n\n")
    return
  }
  let (text, language) = match value {
    String(s) => (s, "text")
    _ => (canonical(value), "json")
  }
  let mut end = preview_chars.min(text.length())
  if end < text.length() && end > 0 {
    let unit = text[end - 1].to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      end -= 1
    }
  }
  self.block(text[:end].to_owned(), language)
  if end < text.length() {
    self.write(
      "Preview omitted " +
      (text.length() - end).to_string() +
      " UTF-16 units; use JSON for full evidence.\n\n",
    )
  }
}

///|
fn MarkdownWriter::change(
  self : MarkdownWriter,
  change : Change,
  number : Int32,
  preview_chars : Int32,
) -> Unit raise ReviewError {
  self.write("### " + number.to_string() + ". " + change.kind.label() + "\n\n")
  self.block(
    canonical({
      "cell_id": change.cell_id.map(Json::string).unwrap_or(Json::null()),
      "path": Json(change.path),
      "suppressed_by": change.suppressed_by
      .map(Json::string)
      .unwrap_or(Json::null()),
    }),
    "json",
  )
  self.write("Before:\n\n")
  self.value(change.before, preview_chars)
  self.write("After:\n\n")
  self.value(change.after, preview_chars)
}

///|
/// Human-readable review with explicit bounded previews and complete locations.
/// Preview size is 32..4096 UTF-16 units per before/after representation; a
/// surrogate pair is never split. The complete report is limited to 1000000
/// units, raising rather than returning partial Markdown. JSON/bundles are unchanged.
pub fn Comparison::to_markdown(
  self : Comparison,
  preview_chars~ : Int32 = 240,
) -> String raise ReviewError {
  guard preview_chars >= 32 && preview_chars <= 4096 else {
    raise Invalid("preview_chars must be 32..4096; use JSON for full evidence")
  }
  let out : MarkdownWriter = { buffer: StringBuilder(), size: 0, }
  let active = self.items.filter(c => c.suppressed_by is None)
  let suppressed = self.items.filter(c => c.suppressed_by is Some(_))
  out.write(
    "# Notebook review\n\nActive changes: " +
    active.length().to_string() +
    "\n\nSuppressed changes: " +
    suppressed.length().to_string() +
    "\n\n",
  )
  out.write(
    "Values below are bounded previews. Full evidence is available in the JSON report or replay bundle.\n\n",
  )
  for
    (title, items) in [
      ("Active changes", active),
      ("Suppressed changes", suppressed),
    ] {
    out.write("## " + title + "\n\n")
    if items.is_empty() {
      out.write("None.\n\n")
    }
    for i, change in items {
      out.change(change, i + 1, preview_chars)
    }
  }
  out.buffer.to_string()
}
