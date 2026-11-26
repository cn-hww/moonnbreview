///|
// Git --name-status -z emits status NUL path NUL with rename detection disabled.
// Keep framing strict; never infer absence from failed blob reads.
fn discovered_manifest(text : String) -> @review.FileManifest raise {
  if text.is_empty() {
    return @review.FileManifest::new([])
  }
  guard text.has_suffix("\u0000") else {
    fail("Git discovery output is not NUL terminated")
  }
  let parts = text.split("\u0000").collect()
  guard parts.length() % 2 == 1 else {
    fail("Git discovery has an incomplete status/path record")
  }
  let statuses : Map[String, String] = Map([])
  let paths : Array[String] = []
  let mut i = 0
  while i + 1 < parts.length() {
    let status = parts[i].to_owned()
    let path = parts[i + 1].to_owned()
    guard ["A", "D", "M", "T"].contains(status) && !path.is_empty() else {
      fail("unexpected Git discovery status or empty path: " + status)
    }
    if path.has_suffix(".ipynb") {
      validate_path(path)
      guard !statuses.contains(path) else {
        fail("duplicate Git discovery path: " + path)
      }
      guard paths.length() < 64 else {
        fail(
          "Git discovery exceeds 64 notebooks; split the review using explicit manifests",
        )
      }
      statuses[path] = status
      paths.push(path)
    }
    i += 2
  }
  paths.sort()
  @review.FileManifest::new(
    paths.mapi((i, path) => {
      let status = statuses[path]
      @review.FilePair::{
        id: "file-" + (i + 1).to_string(),
        old_path: if status == "A" {
          None
        } else {
          Some(path)
        },
        new_path: if status == "D" {
          None
        } else {
          Some(path)
        },
      }
    }),
  )
}

///|
/// Discover changed lowercase '.ipynb' paths between the pinned endpoint commits.
/// Adds/deletes are explicit; modifications/type changes keep both paths. Renames
/// are deliberately add+delete, including moves across the selected suffix.
/// No merge-base inference, checkout, external diff or textconv. Deterministic
/// manifest-2 order/ordinal IDs; 64 notebooks, 2MB diff capture, 30s timeout.
/// Nonregular selected files produce normal per-pair errors during review_files.
pub async fn Revisions::discover(self : Revisions) -> @review.FileManifest {
  discovered_manifest(
    @utf8.decode(
      git(
        self.repository,
        [
          "diff",
          "--name-status",
          "-z",
          "--no-renames",
          "--no-relative",
          "--no-ext-diff",
          "--no-textconv",
          "--ignore-submodules=none",
          self.old_id,
          self.new_id,
          "--",
        ],
        2000000,
      ),
    ),
  )
}
