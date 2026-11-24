///|
fn read(path : String) -> String raise {
  @utf8.decode(@fs.read_file_to_bytes(path))
}

///|
#cfg(target="js")
fn arguments() -> Array[String] {
  @env.args()[1:].to_owned()
}

///|
#cfg(not(target="js"))
fn arguments() -> Array[String] {
  @env.args()
}

///|
fn format(text : String) -> String raise {
  guard ["json", "junit", "markdown"].contains(text) else {
    fail("--format must be json, junit or markdown")
  }
  text
}

///|
fn render(
  batch : @review.BatchReview,
  format : String,
  focus : Bool,
) -> String raise {
  if format == "junit" {
    @junit.render(batch)
  } else if format == "markdown" {
    batch.to_markdown(focus_changes=focus)
  } else {
    batch.to_json()
  }
}

///|
fn main {
  try {
    let args = arguments()
    if args.length() == 2 && ["--help", "-h"].contains(args[1]) {
      println(
        (
          #|MoonNBReview 0.1.0 — notebook file batch
          #|review|check|bundle MANIFEST [--policy FILE]
          #|replay BATCH_BUNDLE [--format json|junit|markdown]
          #|review/check: --format json|junit|markdown
          #|check/bundle only: --gate FILE (blocking categories)
          #|--focus-changes requires Markdown and may occur once.
          #|Bundles have fixed JSON format. Replay accepts no policy/gate override.
          #|Exit: check/replay 0 passed / 1 blocked / 2 errors; review/bundle 0 valid / 2 errors.
          #|Every pair is retained, including failures. See docs/cli.md.
        ),
      )
      return
    }
    if args.length() == 2 && args[1] == "--version" {
      println("moonnbreview-batch 0.1.0")
      return
    }
    guard args.length() >= 3 &&
      ["review", "check", "bundle", "replay"].contains(args[1]) else {
      fail(
        "usage: review|check MANIFEST.json [--format json|junit|markdown] [--focus-changes] [--policy FILE] [--gate FILE (check)] | bundle MANIFEST.json [--policy FILE] [--gate FILE] | replay BUNDLE.json [--format json|junit|markdown] [--focus-changes]",
      )
    }
    let mut policy_path : String? = None
    let mut gate_path : String? = None
    let mut output_format : String? = None
    let mut focus_changes = false
    let mut i = 3
    while i < args.length() {
      if args[i] == "--focus-changes" {
        guard !focus_changes else { fail("--focus-changes may occur once") }
        focus_changes = true
        i += 1
        continue
      }
      guard i + 1 < args.length() else { fail("option requires a file") }
      match args[i] {
        "--format" => {
          guard output_format is None && args[1] != "bundle" else {
            fail(
              "--format may occur once on review/check; bundles have a fixed JSON format",
            )
          }
          output_format = Some(format(args[i + 1]))
        }
        "--policy" => {
          guard args[1] != "replay" && policy_path is None else {
            fail(
              "--policy may occur once on review/check/bundle; replay uses its retained policy",
            )
          }
          policy_path = Some(args[i + 1])
        }
        "--gate" => {
          guard ["check", "bundle"].contains(args[1]) && gate_path is None else {
            fail("--gate may occur once, for check or bundle only")
          }
          gate_path = Some(args[i + 1])
        }
        _ => fail("unknown argument: " + args[i])
      }
      i += 2
    }
    guard !focus_changes || output_format == Some("markdown") else {
      fail("--focus-changes requires --format markdown on review/check/replay")
    }
    if args[1] == "replay" {
      let replay = @review.BatchReview::from_bundle(read(args[2]))
      println(render(replay, output_format.unwrap_or("json"), focus_changes))
      @env.exit(replay.exit_code())
    }
    let policy = match policy_path {
      Some(path) => @review.Policy::from_json(read(path))
      None => @review.Policy::new()
    }
    let gate = match gate_path {
      Some(path) => @review.Gate::from_json(read(path))
      None => @review.Gate::new()
    }
    let report = @review.Manifest::from_json(read(args[2])).review(
      read,
      policy~,
      gate~,
      retain_inputs=args[1] == "bundle",
    )
    println(
      if args[1] == "bundle" {
        report.to_bundle()
      } else {
        render(report, output_format.unwrap_or("json"), focus_changes)
      },
    )
    let code = report.exit_code()
    if code == 2 || (args[1] == "check" && code != 0) {
      @env.exit(code)
    }
  } catch {
    e => {
      println("\{Repr(e)}")
      @env.exit(2)
    }
  }
}
