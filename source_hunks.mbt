///|
/// A line retains its original LF, when present. CR is ordinary source content.
pub struct SourceLine {
  kind : SourceLineKind
  text : String
  old_line : Int32?
  new_line : Int32?
}

///|
#derive(Debug, Eq)
pub(all) enum SourceLineKind {
  Context
  Added
  Removed
}

///|
/// Absolute, one-based line locations; header uses unified diff range notation.
pub struct SourceHunk {
  header : String
  lines : Array[SourceLine]
}

///|
fn source_lines(text : String) -> Array[String] {
  let lines = []
  let mut start = 0
  for i in 0..<text.length() {
    if text[i].to_int() == 10 {
      lines.push(text[start:i + 1].to_owned())
      start = i + 1
    }
  }
  if start < text.length() {
    lines.push(text[start:].to_owned())
  }
  lines
}

///|
/// Exhaustive line hunks for paired cell /source witnesses, otherwise None.
/// Limits: context 0..20, combined 200000 UTF-16 units and 4000 lines.
/// Uses core/diff Myers with cutoff 1000: complete, deterministic edits, not
/// necessarily a minimal edit script. Exceeding a limit refuses, never clips.
/// Each call returns fresh arrays; JSON evidence and gate semantics are unchanged.
pub fn Change::source_hunks(
  self : Change,
  context~ : Int32 = 3,
) -> Array[SourceHunk]? raise ReviewError {
  guard context >= 0 && context <= 20 else {
    raise Invalid("source hunk context must be 0..20")
  }
  guard self.kind == Source && self.cell_id is Some(_) && self.path == "/source" else {
    return None
  }
  guard self.before is Some(String(before)) && self.after is Some(String(after)) else {
    return None
  }
  guard before.length() + after.length() <= 200000 else {
    raise Invalid(
      "source hunks exceed 200000 combined UTF-16 units; use JSON for full evidence",
    )
  }
  let old = source_lines(before)
  let new = source_lines(after)
  guard old.length() + new.length() <= 4000 else {
    raise Invalid(
      "source hunks exceed 4000 combined lines; use JSON for full evidence",
    )
  }
  let diff = @diff.Diff(old=old[:], new=new[:], algorithm=Myers, cutoff=1000)
  Some(
    diff
    .group(context~)
    .map(hunk => {
      let lines = []
      for edit in hunk.edits() {
        match edit {
          Delete(old_index~, old_len~, ..) =>
            for i in old_index..<(old_index + old_len) {
              lines.push({
                kind: Removed,
                text: old[i],
                old_line: Some(i + 1),
                new_line: None,
              })
            }
          Insert(new_index~, new_len~, ..) =>
            for i in new_index..<(new_index + new_len) {
              lines.push({
                kind: Added,
                text: new[i],
                old_line: None,
                new_line: Some(i + 1),
              })
            }
          Equal(old_index~, new_index~, len~) =>
            for i in 0..<len {
              lines.push({
                kind: Context,
                text: old[old_index + i],
                old_line: Some(old_index + i + 1),
                new_line: Some(new_index + i + 1),
              })
            }
        }
      }
      { header: hunk.header(), lines, }
    }),
  )
}

///|
fn MarkdownWriter::source(
  self : MarkdownWriter,
  hunks : Array[SourceHunk],
) -> Unit raise ReviewError {
  self.write(
    "Source line hunks (all edits; 3 context lines; LF retained, CR shown as \\u000d):\n\n",
  )
  for hunk in hunks {
    let text = StringBuilder()
    text.write_string(hunk.header + "\n")
    for line in hunk.lines {
      text.write_string(
        match line.kind {
          Context => " "
          Added => "+"
          Removed => "-"
        },
      )
      text.write_string(line.text)
      if !line.text.has_suffix("\n") {
        text.write_string("\n\\ No newline at end of file\n")
      }
    }
    self.block(text.to_string(), "diff")
  }
}
