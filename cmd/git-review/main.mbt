///|
async fn main {
  try {
    let args = @env.args()
    guard args.length() >= 6 && ["review", "check", "bundle"].contains(args[1]) else {
      fail(
        "usage: review|check|bundle REPO OLD_REF NEW_REF PATH [--policy FILE] [--format json|markdown|html]; check also accepts --gate FILE",
      )
    }
    let mut policy_path : String? = None
    let mut format : String? = None
    let mut focus_changes = false
    let mut gate_path : String? = None
    let mut i = 6
    while i < args.length() {
      if args[i] == "--focus-changes" {
        guard !focus_changes else { fail("--focus-changes may occur once") }
        focus_changes = true
        i += 1
        continue
      }
      guard i + 1 < args.length() else { fail("option requires a value") }
      match args[i] {
        "--gate" => {
          guard args[1] == "check" && gate_path is None else {
            fail("--gate may occur once and is only valid for check")
          }
          gate_path = Some(args[i + 1])
        }
        "--policy" => {
          guard policy_path is None else { fail("--policy may occur once") }
          policy_path = Some(args[i + 1])
        }
        "--format" => {
          guard format is None &&
            ["json", "markdown", "html"].contains(args[i + 1]) else {
            fail("--format requires json, markdown or html and may occur once")
          }
          format = Some(args[i + 1])
        }
        _ => fail("unknown argument: " + args[i])
      }
      i += 2
    }
    guard args[1] != "bundle" || format is None else {
      fail("bundle has a fixed JSON format; omit --format")
    }
    guard !focus_changes || (format == Some("markdown") && args[1] != "bundle") else {
      fail("--focus-changes requires --format markdown on review or check")
    }
    let policy = match policy_path {
      Some(path) => @review.Policy::from_json(@fs.read_file(path).text())
      None => @review.Policy::new()
    }
    let gate = match gate_path {
      Some(path) => @review.Gate::from_json(@fs.read_file(path).text())
      None => @review.Gate::new()
    }
    let old = @snapshots.Snapshot::load(args[2], args[3], args[5])
    let new = @snapshots.Snapshot::load(args[2], args[4], args[5])
    let comparison = @review.compare(old.document(), new.document(), policy~)
    let text = if args[1] == "bundle" {
      comparison.to_bundle()
    } else if format == Some("markdown") {
      comparison.to_markdown(focus_changes~)
    } else if format == Some("html") {
      comparison.to_html()
    } else {
      comparison.to_json()
    }
    println(text)
    if args[1] == "check" && !comparison.passes(blocked=gate.blocked()) {
      @env.exit(1)
    }
  } catch {
    e => {
      println("\{Repr(e)}")
      @env.exit(2)
    }
  }
}
