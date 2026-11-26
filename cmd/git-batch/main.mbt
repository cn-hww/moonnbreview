///|
async fn main {
  try {
    let args = @env.args()
    if args.length() == 2 && ["--help", "-h"].contains(args[1]) {
      println(
        (
          #|MoonNBReview 0.1.0 — committed notebook batch (Wasm/native)
          #|review|check|bundle REPO OLD_REF NEW_REF [MANIFEST] [--policy FILE]
          #|Omit MANIFEST to discover changed lowercase .ipynb files automatically.
          #|discover REPO OLD_REF NEW_REF prints the selected manifest-2 only.
          #|check/bundle only: --gate FILE
          #|review/check: --format json|junit|markdown
          #|--focus-changes requires Markdown and may occur once.
          #|Bundles have fixed JSON format; replay them with the file batch command.
          #|Both refs are pinned before serial pair loading. No checkout or rename inference.
          #|Exit: check 0 passed / 1 blocked / 2 errors; review/bundle 0 valid / 2 errors.
          #|Git must be on PATH. See docs/cli.md.
        ),
      )
      return
    }
    if args.length() == 2 && args[1] == "--version" {
      println("moonnbreview-git-batch 0.1.0")
      return
    }
    if args.length() >= 2 && args[1] == "discover" {
      guard args.length() == 5 else {
        fail("usage: discover REPO OLD_REF NEW_REF; no review options")
      }
      let revisions = @snapshots.Revisions::resolve(args[2], args[3], args[4])
      println(revisions.discover().to_json())
      return
    }
    guard args.length() >= 5 && ["review", "check", "bundle"].contains(args[1]) else {
      fail(
        "usage: review|check|bundle REPO OLD_REF NEW_REF [MANIFEST] [--policy FILE] [--gate FILE] [--format json|junit|markdown] [--focus-changes] | discover REPO OLD_REF NEW_REF",
      )
    }
    let mut policy_path : String? = None
    let mut gate_path : String? = None
    let mut format : String? = None
    let mut focus_changes = false
    let manifest_path = if args.length() > 5 && !args[5].has_prefix("--") {
      Some(args[5])
    } else {
      None
    }
    let mut i = if manifest_path is Some(_) { 6 } else { 5 }
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
    let explicit = match manifest_path {
      Some(path) =>
        Some(@review.FileManifest::from_json(@fs.read_file(path).text()))
      None => None
    }
    let revisions = @snapshots.Revisions::resolve(args[2], args[3], args[4])
    let manifest = match explicit {
      Some(plan) => plan
      None => revisions.discover()
    }
    let batch = revisions.review_files(
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
