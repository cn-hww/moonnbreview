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
  guard ["json", "junit"].contains(text) else {
    fail("--format must be json or junit")
  }
  text
}

///|
fn render(batch : @review.BatchReview, format : String) -> String raise {
  if format == "junit" {
    @junit.render(batch)
  } else {
    batch.to_json()
  }
}

///|
fn main {
  try {
    let args = arguments()
    guard args.length() >= 3 &&
      ["review", "check", "bundle", "replay"].contains(args[1]) else {
      fail(
        "usage: review|check MANIFEST.json [--format json|junit] [--policy FILE] [--gate FILE (check)] | bundle MANIFEST.json [--policy FILE] [--gate FILE] | replay BUNDLE.json [--format json|junit]",
      )
    }
    if args[1] == "replay" {
      guard args.length() == 3 || (args.length() == 5 && args[3] == "--format") else {
        fail(
          "batch replay accepts only its bundle; no replacement policy or gate",
        )
      }
      let output_format = if args.length() == 5 {
        format(args[4])
      } else {
        "json"
      }
      let replay = @review.BatchReview::from_bundle(read(args[2]))
      println(render(replay, output_format))
      @env.exit(replay.exit_code())
    }
    let mut policy_path : String? = None
    let mut gate_path : String? = None
    let mut output_format : String? = None
    let mut i = 3
    while i < args.length() {
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
          guard policy_path is None else { fail("--policy may occur once") }
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
        render(report, output_format.unwrap_or("json"))
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
