///|
/// Two symbolic revisions pinned to full commit IDs for an entire batch.
/// Resolving the two names is sequential; pass full IDs for caller-atomic selection.
pub struct Revisions {
  priv repository : String
  priv old_id : String
  priv new_id : String
}

///|
pub async fn Revisions::resolve(
  repository : String,
  old_revision : String,
  new_revision : String,
) -> Revisions {
  let old_id = resolve_commit(repository, old_revision)
  let new_id = resolve_commit(repository, new_revision)
  { repository, old_id, new_id, }
}

///|
pub fn Revisions::old_commit(self : Revisions) -> String {
  self.old_id
}

///|
pub fn Revisions::new_commit(self : Revisions) -> String {
  self.new_id
}

///|
/// Review literal old/new root-relative paths, including explicit renames.
/// No checkout, discovery, rename guessing or missing-file-as-empty fallback.
/// Reads are serial and per-pair errors continue; no whole-batch preload/cache.
/// Returned batch/bundle formats contain paths but not Git provenance; archive
/// old_commit/new_commit separately when that provenance is required.
pub async fn Revisions::review(
  self : Revisions,
  manifest : @review.Manifest,
  policy~ : @review.Policy = @review.Policy::new(),
  gate~ : @review.Gate = @review.Gate::new(),
  retain_inputs~ : Bool = false,
) -> @review.BatchReview {
  manifest.review_sides_async(
    path => load_text(self.repository, self.old_id, path),
    path => load_text(self.repository, self.new_id, path),
    policy~,
    gate~,
    retain_inputs~,
  )
}

///|
/// Explicit additions/deletions use absent paths; existing paths still fail
/// normally on IO/format errors. No file identity or absence is inferred here.
pub async fn Revisions::review_files(
  self : Revisions,
  manifest : @review.FileManifest,
  policy~ : @review.Policy = @review.Policy::new(),
  gate~ : @review.Gate = @review.Gate::new(),
  retain_inputs~ : Bool = false,
) -> @review.BatchReview {
  manifest.review_sides_async(
    path => load_text(self.repository, self.old_id, path),
    path => load_text(self.repository, self.new_id, path),
    policy~,
    gate~,
    retain_inputs~,
  )
}
