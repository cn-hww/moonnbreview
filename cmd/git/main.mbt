///|
async fn main {
  try {
    let args = @env.args()
    guard args.length() >= 6 && ["review", "check", "bundle"].contains(args[1]) else {
      fail(
        "usage: review|check|bundle REPO OLD_REF NEW_REF PATH [--policy FILE] [--format json|markdown]",
      )
    }
    let mut policy_path : String? = None
    let mut format : String? = None
    let mut i = 6
    while i < args.length() {
      guard i + 1 < args.length() else { fail("option requires a value") }
      match args[i] {
        "--policy" => {
          guard policy_path is None else { fail("--policy may occur once") }
          policy_path = Some(args[i + 1])
        }
        "--format" => {
          guard format is None && ["json", "markdown"].contains(args[i + 1]) else {
            fail("--format requires json or markdown and may occur once")
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
    let policy = match policy_path {
      Some(path) => @review.Policy::from_json(@fs.read_file(path).text())
      None => @review.Policy::new()
    }
    let old = @snapshots.Snapshot::load(args[2], args[3], args[5])
    let new = @snapshots.Snapshot::load(args[2], args[4], args[5])
    let comparison = @review.compare(old.document(), new.document(), policy~)
    let text = if args[1] == "bundle" {
      comparison.to_bundle()
    } else if format == Some("markdown") {
      comparison.to_markdown()
    } else {
      comparison.to_json()
    }
    println(text)
    if args[1] == "check" && !comparison.passes() {
      @env.exit(1)
    }
  } catch {
    e => {
      println("\{Repr(e)}")
      @env.exit(2)
    }
  }
}
