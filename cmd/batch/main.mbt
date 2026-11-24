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
fn main {
  try {
    let args = arguments()
    guard args.length() >= 3 &&
      ["review", "check", "bundle", "replay"].contains(args[1]) else {
      fail(
        "usage: review|check|bundle MANIFEST.json [--policy FILE] [--gate FILE (check/bundle)] | replay BUNDLE.json",
      )
    }
    if args[1] == "replay" {
      guard args.length() == 3 else {
        fail(
          "batch replay accepts only its bundle; no replacement policy or gate",
        )
      }
      let replay = @review.BatchReview::from_bundle(read(args[2]))
      println(replay.to_json())
      @env.exit(replay.exit_code())
    }
    let mut policy_path : String? = None
    let mut gate_path : String? = None
    let mut i = 3
    while i < args.length() {
      guard i + 1 < args.length() else { fail("option requires a file") }
      match args[i] {
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
        report.to_json()
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
