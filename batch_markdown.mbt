///|
fn markdown_string(value : Json) -> String raise ReviewError {
  guard value is String(text) else {
    raise Invalid("expected internal batch string")
  }
  text
}

///|
fn markdown_nullable(value : Json) -> String? raise ReviewError {
  match value {
    Null => None
    String(text) => Some(text)
    _ => raise Invalid("expected internal nullable batch string")
  }
}

///|
// This reads only immutable reports created by BatchWriter, not external reports.
// Missing before/after fields must remain distinct from explicit JSON null.
fn markdown_change(value : Json) -> Change raise ReviewError {
  let fields = object(value)
  {
    kind: gate_kind(markdown_string(fields["kind"])),
    cell_id: markdown_nullable(fields["cell_id"]),
    path: markdown_string(fields["path"]),
    before: fields.get("before"),
    after: fields.get("after"),
    suppressed_by: markdown_nullable(fields["suppressed_by"]),
  }
}

///|
/// Human-readable batch review with complete IDs/paths/configuration/diagnostics
/// and every active/suppressed change. Values use the same 32..4096 UTF-16 unit
/// previews, safe fences and optional first-difference focus as single reviews.
/// Total output is capped at 1M units, refusing instead of dropping entries.
/// Works without retained inputs; JSON, bundle and gate outcomes are unchanged.
/// source_hunks=true shows all paired source edits, excluding focus_changes.
pub fn BatchReview::to_markdown(
  self : BatchReview,
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
  let root = object(
    @json.parse(self.report, max_nesting_depth=80, preserve_number_repr=true) catch {
      e => raise Invalid("invalid internal batch JSON: " + e.to_string())
    },
  )
  guard root["results"] is Array(entries) else {
    raise Invalid("expected internal batch results")
  }
  let out : MarkdownWriter = { buffer: StringBuilder(), size: 0, }
  out.write(
    "# Notebook batch review\n\nExit code: " +
    self.code.to_string() +
    " (0: passed; 1: blocked; 2: errors).\n\n",
  )
  out.write(
    "Values are bounded previews; full evidence is in the JSON report or retained replay bundle. Every pair, change location and diagnostic is included.\n\n",
  )
  if focus_changes {
    out.write(
      "Paired string previews focus on the first difference; later edits may be omitted. Other values use prefix previews.\n\n",
    )
  }
  out.write("## Summary\n\n")
  out.block(canonical(root["summary"]), "json")
  out.write("## Configuration\n\n")
  out.block(
    canonical({ "policy": root["policy"], "gate": root["gate"] }),
    "json",
  )
  if entries.is_empty() {
    out.write("No notebook pairs.\n\n")
  }
  for i, entry in entries {
    let fields = object(entry)
    let status = markdown_string(fields["status"])
    guard ["passed", "blocked", "error"].contains(status) else {
      raise Invalid("unknown internal batch status")
    }
    out.write("## Notebook " + (i + 1).to_string() + ": " + status + "\n\n")
    out.block(
      canonical({
        "id": fields["id"],
        "old": fields["old"],
        "new": fields["new"],
        "status": fields["status"],
      }),
      "json",
    )
    if status == "error" {
      out.write("### Diagnostic\n\n")
      out.block(canonical(fields["diagnostic"]), "json")
    } else {
      let report = object(fields["report"])
      for
        (title, key) in [
          ("Active changes", "changes"),
          ("Suppressed changes", "suppressed"),
        ] {
        guard report[key] is Array(changes) else {
          raise Invalid("expected internal change list")
        }
        out.write("### " + title + ": " + changes.length().to_string() + "\n\n")
        if changes.is_empty() {
          out.write("None.\n\n")
        }
        for j, change in changes {
          out.change(
            markdown_change(change),
            j + 1,
            preview_chars,
            focus_changes,
            source_hunks,
            heading="####",
          )
        }
      }
    }
  }
  out.buffer.to_string()
}
