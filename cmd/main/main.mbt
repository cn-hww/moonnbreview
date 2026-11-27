///|
fn read(path : String) -> String raise {
  @utf8.decode(@fs.read_file_to_bytes(path))
}

///|
// Let Node drain asynchronous stdout before a nonzero exit.
#cfg(target="js")
extern "js" fn finish(code : Int32) -> Unit = "(code) => { process.exitCode = code; }"

///|
#cfg(not(target="js"))
fn finish(code : Int32) -> Unit {
  @env.exit(code)
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
  guard ["json", "markdown", "html"].contains(text) else {
    fail("--format must be json, markdown or html")
  }
  text
}

///|
fn main {
  try {
    let args = arguments()
    if args.length() == 2 && ["--help", "-h"].contains(args[1]) {
      println(
        (
          #|MoonNBReview 0.1.0 — notebook file review
          #|review|check|bundle OLD NEW [--policy FILE]
          #|validate NOTEBOOK (structured diagnostics; exit 0 accepted / 2 refused)
          #|replay BUNDLE [--format json|markdown|html]
          #|review/check: --format json|markdown|html
          #|check only: --gate FILE (blocking categories)
          #|Inline policy: --ignore-execution-counts; --ignore-metadata KEY (repeatable)
          #|--policy cannot be mixed with inline policy flags.
          #|--focus-changes requires Markdown; --group-mime requires HTML (each once).
          #|--source-hunks shows every source edit in Markdown; excludes --focus-changes.
          #|Bundles have fixed JSON format. Replay accepts no policy/gate override.
          #|Exit: check 0 passed / 1 blocked / 2 invalid; review/bundle/replay 0 valid / 2 invalid.
          #|Reports go to stdout; inputs are never rewritten. See docs/cli.md.
        ),
      )
      return
    }
    if args.length() == 2 && args[1] == "--version" {
      println("moonnbreview 0.1.0")
      return
    }
    if args.length() >= 2 && args[1] == "validate" {
      guard args.length() == 3 else { fail("usage: validate NOTEBOOK.ipynb") }
      match @review.Document::validate(read(args[2])) {
        Ok(_) =>
          println(
            "{\"format\":\"moonnbreview/validation-1\",\"valid\":true,\"diagnostic\":null}",
          )
        Err(diagnostic) => {
          println(
            "{\"format\":\"moonnbreview/validation-1\",\"valid\":false,\"diagnostic\":" +
            diagnostic.to_json() +
            "}",
          )
          finish(2)
        }
      }
      return
    }
    guard args.length() >= 2 else {
      fail(
        "usage: review|check OLD NEW [--policy FILE] [--format json|markdown|html] | check ... --gate FILE | bundle OLD NEW [--policy FILE] | replay BUNDLE [--format json|markdown|html]",
      )
    }
    let command = args[1]
    let mut format = "json"
    let mut focus_changes = false
    let mut source_hunks = false
    let mut group_mime = false
    let mut gate_path : String? = None
    let comparison = if command == "replay" {
      guard args.length() >= 3 else {
        fail(
          "usage: replay BUNDLE.json [--format json|markdown|html] [--focus-changes]",
        )
      }
      let mut explicit_format = false
      let mut i = 3
      while i < args.length() {
        match args[i] {
          "--source-hunks" => {
            guard !source_hunks else { fail("--source-hunks may occur once") }
            source_hunks = true
          }
          "--group-mime" => {
            guard !group_mime else { fail("--group-mime may occur once") }
            group_mime = true
          }
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
          "--source-hunks" => {
            guard !source_hunks else { fail("--source-hunks may occur once") }
            source_hunks = true
          }
          "--group-mime" => {
            guard !group_mime else { fail("--group-mime may occur once") }
            group_mime = true
          }
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
    guard !source_hunks ||
      (format == "markdown" && command != "bundle" && !focus_changes) else {
      fail(
        "--source-hunks requires Markdown review/check/replay and excludes --focus-changes",
      )
    }
    let gate = match gate_path {
      Some(path) => @review.Gate::from_json(read(path))
      None => @review.Gate::new()
    }
    guard !group_mime || (format == "html" && command != "bundle") else {
      fail("--group-mime requires --format html on review, check or replay")
    }
    let text = if command == "bundle" {
      comparison.to_bundle()
    } else if format == "markdown" {
      comparison.to_markdown(focus_changes~, source_hunks~)
    } else if format == "html" {
      comparison.to_html(group_mime~)
    } else {
      comparison.to_json()
    }
    println(text)
    if command == "check" && !comparison.passes(blocked=gate.blocked()) {
      finish(1)
    }
  } catch {
    e => {
      // Error strings are JSON escaped by Debug; terminal control bytes are not emitted.
      println("\{Repr(e)}")
      finish(2)
    }
  }
}
