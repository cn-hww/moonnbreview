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
    guard args.length() >= 2 else {
      fail(
        "usage: review|check|bundle OLD.ipynb NEW.ipynb [--ignore-execution-counts] [--ignore-metadata KEY] | replay BUNDLE.json",
      )
    }
    let command = args[1]
    let comparison = if command == "replay" {
      guard args.length() == 3 else { fail("usage: replay BUNDLE.json") }
      @review.Comparison::from_bundle(read(args[2]))
    } else {
      guard ["review", "check", "bundle"].contains(command) &&
        args.length() >= 4 else {
        fail("expected review|check|bundle OLD NEW")
      }
      let mut counts = false
      let keys = []
      let mut i = 4
      while i < args.length() {
        match args[i] {
          "--ignore-execution-counts" => counts = true
          "--ignore-metadata" => {
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
      @review.compare(
        @review.Document::parse(read(args[2])),
        @review.Document::parse(read(args[3])),
        policy=@review.Policy::new(
          ignore_execution_counts=counts,
          ignored_metadata_keys=keys,
        ),
      )
    }
    let text = if command == "bundle" {
      comparison.to_bundle()
    } else {
      comparison.to_json()
    }
    println(text)
    if command == "check" && !comparison.passes() {
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
