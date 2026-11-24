///|
async fn main {
  try {
    let args = @env.args()
    guard args.length() >= 6 && ["review", "check", "bundle"].contains(args[1]) else {
      fail(
        "usage: review|check|bundle REPO OLD_REF NEW_REF MANIFEST [--policy FILE] [--gate FILE] [--format json|junit|markdown] [--focus-changes]",
      )
    }
    let mut policy_path : String? = None
    let mut gate_path : String? = None
    let mut format : String? = None
    let mut focus_changes = false
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
        "--policy" => {
          guard policy_path is None else { fail("--policy may occur once") }
          policy_path = Some(args[i + 1])
        }
        "--gate" => {
          guard args[1] != "review" && gate_path is None else {
            fail("--gate may occur once on check or bundle")
          }
          gate_path = Some(args[i + 1])
        }
        "--format" => {
          guard args[1] != "bundle" &&
            format is None &&
            ["json", "junit", "markdown"].contains(args[i + 1]) else {
            fail(
              "--format json|junit|markdown may occur once on review or check",
            )
          }
          format = Some(args[i + 1])
        }
        _ => fail("unknown argument: " + args[i])
      }
      i += 2
    }
    guard !focus_changes || format == Some("markdown") else {
      fail("--focus-changes requires --format markdown on review/check")
    }
    let policy = match policy_path {
      Some(path) => @review.Policy::from_json(@fs.read_file(path).text())
      None => @review.Policy::new()
    }
    let gate = match gate_path {
      Some(path) => @review.Gate::from_json(@fs.read_file(path).text())
      None => @review.Gate::new()
    }
    let manifest = @review.Manifest::from_json(@fs.read_file(args[5]).text())
    let revisions = @snapshots.Revisions::resolve(args[2], args[3], args[4])
    let batch = revisions.review(
      manifest,
      policy~,
      gate~,
      retain_inputs=args[1] == "bundle",
    )
    println(
      if args[1] == "bundle" {
        batch.to_bundle()
      } else if format == Some("junit") {
        @junit.render(batch)
      } else if format == Some("markdown") {
        batch.to_markdown(focus_changes~)
      } else {
        batch.to_json()
      },
    )
    if batch.exit_code() == 2 || args[1] == "check" {
      @env.exit(batch.exit_code())
    }
  } catch {
    e => {
      println("\{Repr(e)}")
      @env.exit(2)
    }
  }
}
