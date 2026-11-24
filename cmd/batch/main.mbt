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
    guard args.length() >= 3 && ["review", "check"].contains(args[1]) else {
      fail(
        "usage: review|check MANIFEST.json [--policy FILE] [--gate FILE (check only)]",
      )
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
          guard args[1] == "check" && gate_path is None else {
            fail("--gate may occur once, for check only")
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
    )
    println(report.to_json())
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
