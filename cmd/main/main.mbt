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
fn output_format(text : String) -> String raise {
  guard text == "json" || text == "markdown" else {
    fail("--format must be json or markdown")
  }
  text
}

///|
fn main {
  try {
    let args = arguments()
    guard args.length() >= 2 else {
      fail(
        "usage: review|check OLD NEW [--policy FILE] [--format json|markdown] | bundle OLD NEW [--policy FILE] | replay BUNDLE [--format json|markdown]",
      )
    }
    let command = args[1]
    let mut format = "json"
    let mut focus_changes = false
    let mut gate_path : String? = None
    let comparison = if command == "replay" {
      guard args.length() >= 3 else {
        fail(
          "usage: replay BUNDLE.json [--format json|markdown] [--focus-changes]",
        )
      }
      let mut explicit_format = false
      let mut i = 3
      while i < args.length() {
        match args[i] {
          "--gate" => fail("--gate is only valid for check, not replay")
          "--focus-changes" => {
            guard !focus_changes else { fail("--focus-changes may occur once") }
            focus_changes = true
          }
          "--format" => {
            guard !explicit_format && i + 1 < args.length() else {
              fail("--format requires one value and may occur once")
            }
            explicit_format = true
            i += 1
            format = output_format(args[i])
          }
          _ => fail("unknown replay argument: " + args[i])
        }
        i += 1
      }
      @review.Comparison::from_bundle(read(args[2]))
    } else {
      guard ["review", "check", "bundle"].contains(command) &&
        args.length() >= 4 else {
        fail("expected review|check|bundle OLD NEW")
      }
      let mut counts = false
      let keys = []
      let mut policy_path : String? = None
      let mut inline_policy = false
      let mut explicit_format = false
      let mut i = 4
      while i < args.length() {
        match args[i] {
          "--gate" => {
            guard command == "check" &&
              gate_path is None &&
              i + 1 < args.length() else {
              fail(
                "--gate requires one file, may occur once, and is only valid for check",
              )
            }
            i += 1
            gate_path = Some(args[i])
          }
          "--focus-changes" => {
            guard !focus_changes else { fail("--focus-changes may occur once") }
            focus_changes = true
          }
          "--format" => {
            guard !explicit_format && i + 1 < args.length() else {
              fail("--format requires one value and may occur once")
            }
            explicit_format = true
            i += 1
            format = output_format(args[i])
          }
          "--policy" => {
            guard policy_path is None && i + 1 < args.length() else {
              fail("--policy requires one file and may occur once")
            }
            i += 1
            policy_path = Some(args[i])
          }
          "--ignore-execution-counts" => {
            counts = true
            inline_policy = true
          }
          "--ignore-metadata" => {
            inline_policy = true
            guard i + 1 < args.length() else {
              fail("--ignore-metadata requires an exact key")
            }
            i += 1
            keys.push(args[i])
          }
          _ => fail("unknown argument: " + args[i])
        }
        i += 1
      }
      guard command != "bundle" || !explicit_format else {
        fail("bundle has a fixed JSON format; omit --format")
      }
      guard policy_path is None || !inline_policy else {
        fail(
          "--policy cannot be combined with inline policy flags; edit the policy file explicitly",
        )
      }
      let policy = match policy_path {
        Some(path) => @review.Policy::from_json(read(path))
        None =>
          @review.Policy::new(
            ignore_execution_counts=counts,
            ignored_metadata_keys=keys,
          )
      }
      @review.compare(
        @review.Document::parse(read(args[2])),
        @review.Document::parse(read(args[3])),
        policy~,
      )
    }
    guard !focus_changes || (format == "markdown" && command != "bundle") else {
      fail(
        "--focus-changes requires --format markdown on review, check or replay",
      )
    }
    let gate = match gate_path {
      Some(path) => @review.Gate::from_json(read(path))
      None => @review.Gate::new()
    }
    let text = if command == "bundle" {
      comparison.to_bundle()
    } else if format == "markdown" {
      comparison.to_markdown(focus_changes~)
    } else {
      comparison.to_json()
    }
    println(text)
    if command == "check" && !comparison.passes(blocked=gate.blocked()) {
      @env.exit(1)
    }
  } catch {
    e => {
      // Error strings are JSON escaped by Debug; terminal control bytes are not emitted.
      println("\{Repr(e)}")
      @env.exit(2)
    }
  }
}
