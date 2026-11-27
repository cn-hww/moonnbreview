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
  start : Int32,
  focused : Bool,
) -> Unit raise ReviewError {
  guard value is Some(value) else {
    self.write("Absent.\n\n")
    return
  }
  let (text, language) = match value {
    String(s) => (s, "text")
    _ => (canonical(value), "json")
  }
  let mut end = (start + preview_chars).min(text.length())
  if end < text.length() && end > 0 {
    let unit = text[end - 1].to_int()
    if unit >= 0xD800 && unit <= 0xDBFF {
      end -= 1
    }
  }
  if focused {
    let mut line = 1
    let mut column = 1
    for i in 0..<start {
      if text[i].to_int() == 10 {
        line += 1
        column = 1
      } else {
        column += 1
      }
    }
    self.write(
      "Preview range: UTF-16 [" +
      start.to_string() +
      ", " +
      end.to_string() +
      "); starts at line " +
      line.to_string() +
      ", column " +
      column.to_string() +
      " (1-based UTF-16).\n\n",
    )
  }
  self.block(text[start:end].to_owned(), language)
  if focused && (start > 0 || end < text.length()) {
    self.write(
      "Preview omitted " +
      start.to_string() +
      " UTF-16 units before and " +
      (text.length() - end).to_string() +
      " after; use JSON for full evidence.\n\n",
    )
  } else if end < text.length() {
    self.write(
      "Preview omitted " +
      (text.length() - end).to_string() +
      " UTF-16 units; use JSON for full evidence.\n\n",
    )
  }
}

///|
// Focus on the first differing scalar in a string pair, retaining a quarter
// window of shared context. Both windows start at the same safe boundary.
fn preview_start(before : String, after : String, budget : Int32) -> Int32 {
  let limit = before.length().min(after.length())
  let mut prefix = 0
  while prefix < limit && before[prefix] == after[prefix] {
    prefix += 1
  }
  if prefix > 0 &&
    before[prefix - 1].to_int() >= 0xD800 &&
    before[prefix - 1].to_int() <= 0xDBFF {
    prefix -= 1
  }
  let mut start = (prefix - budget / 4).max(0)
  if start > 0 &&
    before[start - 1].to_int() >= 0xD800 &&
    before[start - 1].to_int() <= 0xDBFF {
    start -= 1
  }
  start
}

///|
fn MarkdownWriter::change(
  self : MarkdownWriter,
  change : Change,
  number : Int32,
  preview_chars : Int32,
  focus_changes : Bool,
  source_hunks : Bool,
  heading~ : String = "###",
) -> Unit raise ReviewError {
  self.write(
    heading + " " + number.to_string() + ". " + change.kind.label() + "\n\n",
  )
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
  if source_hunks {
    if change.source_hunks() is Some(hunks) {
      self.source(hunks)
      return
    }
  }
  let (start, focused) = match (change.before, change.after) {
    (Some(String(a)), Some(String(b))) if focus_changes =>
      (preview_start(a, b, preview_chars), true)
    _ => (0, false)
  }
  self.write("Before:\n\n")
  self.value(change.before, preview_chars, start, focused)
  self.write("After:\n\n")
  self.value(change.after, preview_chars, start, focused)
}

///|
/// Human-readable review with explicit bounded previews and complete locations.
/// Preview size is 32..4096 UTF-16 units per before/after representation; a
/// surrogate pair is never split. The complete report is limited to 1000000
/// units, raising rather than returning partial Markdown. JSON/bundles are unchanged.
/// Set focus_changes=true to center paired string previews near their first
/// difference, with exact original offsets and LF-based line/UTF-16 columns.
/// This is a bounded first-difference view, not an exhaustive text diff.
/// source_hunks=true instead shows every paired /source line edit with context;
/// it excludes focus_changes. Other witness types retain bounded previews.
pub fn Comparison::to_markdown(
  self : Comparison,
  preview_chars~ : Int32 = 240,
  focus_changes~ : Bool = false,
  source_hunks~ : Bool = false,
) -> String raise ReviewError {
  guard !(source_hunks && focus_changes) else {
    raise Invalid("source_hunks and focus_changes are mutually exclusive")
  }
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
  if focus_changes {
    out.write(
      "Paired string previews focus on the first difference; later edits may be omitted. Other values use prefix previews.\n\n",
    )
  }
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
      out.change(change, i + 1, preview_chars, focus_changes, source_hunks)
    }
  }
  out.buffer.to_string()
}
