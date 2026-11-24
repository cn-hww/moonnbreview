///|
/// A validated notebook read from one immutable Git commit, without checkout.
pub struct Snapshot {
  priv commit_id : String
  priv file_path : String
  priv doc : @review.Document
}

///|
pub fn Snapshot::commit(self : Snapshot) -> String {
  self.commit_id
}

///|
/// Repository-root-relative path using '/' separators.
pub fn Snapshot::path(self : Snapshot) -> String {
  self.file_path
}

///|
pub fn Snapshot::document(self : Snapshot) -> @review.Document {
  self.doc
}

///|
fn object_id(text : String) -> Bool {
  (text.length() == 40 || text.length() == 64) &&
  text.iter().all(c => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))
}

///|
fn validate_path(path : String) -> Unit raise {
  guard !path.is_empty() && path.length() <= 4096 else {
    fail("Git path must contain 1..4096 UTF-16 units")
  }
  for c in path {
    guard c != '\\' && c != ':' && c.to_int() >= 32 && c.to_int() != 127 else {
      fail("Git path must use '/' and contain no controls, colon or backslash")
    }
  }
  for part in path.split("/") {
    guard part != "" && part != "." && part != ".." else {
      fail(
        "Git path must be repository-root-relative, without empty or dot components",
      )
    }
  }
}

///|
async fn git(repository : String, args : Array[String], limit : Int32) -> Bytes {
  let argv = ["--no-pager", "--no-replace-objects", "--literal-pathspecs"]
  for arg in args {
    argv.push(arg)
  }
  let result = @shell.Cmd("git", argv, cwd=repository, env={
    "GIT_TERMINAL_PROMPT": "0",
    "GIT_OPTIONAL_LOCKS": "0",
    "GIT_NO_LAZY_FETCH": "1",
  }).output(timeout_ms=30000, max_output_bytes=limit)
  guard result.exit_code() == 0 else {
    fail(
      "Git " +
      args[0] +
      " exited " +
      result.exit_code().to_string() +
      "; stderr: " +
      result.stderr() +
      "; stdout: " +
      result.stdout(),
    )
  }
  result.stdout_bytes()
}

///|
/// Load a regular file from a commit-ish (Git on PATH).
/// Paths are literal and root-relative. No checkout, index update, textconv,
/// smudge filter or lazy fetch is requested. Missing objects, symlinks, trees,
/// invalid UTF-8 and unsupported notebooks raise; they never become empty input.
/// Process calls time out after 30s; blob capture is capped at 6000000 bytes.
pub async fn Snapshot::load(
  repository : String,
  revision : String,
  path : String,
) -> Snapshot {
  validate_path(path)
  guard !revision.is_empty() &&
    revision.length() <= 1024 &&
    revision.iter().all(c => c.to_int() >= 32 && c.to_int() != 127) else {
    fail("Git revision must contain 1..1024 UTF-16 units without controls")
  }
  let commit = @utf8.decode(
      git(
        repository,
        ["rev-parse", "--verify", "--end-of-options", revision + "^{commit}"],
        65536,
      ),
    )
    .trim()
    .to_owned()
  guard object_id(commit) else {
    fail("Git did not resolve exactly one commit")
  }
  let entry = @utf8.decode(
    git(repository, ["ls-tree", "--full-tree", "-z", commit, "--", path], 65536),
  )
  // NUL framing and exact path matching prevent quoting or wildcard ambiguity.
  let suffix = "\t" + path + "\u0000"
  guard entry.has_suffix(suffix) else {
    fail("Git path is missing or is not exactly one file at " + commit)
  }
  let header = entry[:entry.length() - suffix.length()].to_owned()
  let parts = header.split(" ").map(p => p.to_owned()).collect()
  guard parts.length() == 3 &&
    (parts[0] == "100644" || parts[0] == "100755") &&
    parts[1] == "blob" &&
    object_id(parts[2]) else {
    fail(
      "Git path must name one regular file; symlinks, trees and submodules are unsupported",
    )
  }
  let bytes = git(repository, ["cat-file", "blob", parts[2]], 6000000)
  let doc = @review.Document::parse(@utf8.decode(bytes))
  { commit_id: commit, file_path: path, doc, }
}
