///|
async test "Git file manifest reviews whole-file add delete edit and failed presence explicitly" {
  let dir = @fs.tmpdir(prefix="nbreview-git-files-")
  defer cleanup(dir)
  setup_repo(dir, "modified.ipynb")
  @fs.write_file(dir + "/removed.ipynb", sample_before)
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "baseline files"]))
  ignore(run_git(dir, ["rm", "--", "removed.ipynb"]))
  @fs.write_file(dir + "/added.ipynb", sample_after)
  @fs.write_file(dir + "/modified.ipynb", sample_before)
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "file lifecycle"]))
  let revisions = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  let m = @review.FileManifest::new([
    { id: "added", old_path: None, new_path: Some("added.ipynb"), },
    { id: "removed", old_path: Some("removed.ipynb"), new_path: None, },
    {
      id: "modified",
      old_path: Some("modified.ipynb"),
      new_path: Some("modified.ipynb"),
    },
    { id: "missing-is-error", old_path: Some("absent.ipynb"), new_path: None, },
  ])
  let b = revisions.review_files(m, retain_inputs=true)
  assert_eq(b.exit_code(), 2)
  assert_true(b.to_json().contains("read_old"))
  assert_true(b.to_json().contains("file-report-1"))
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
  let legacy = @review.Manifest::new([
    { id: "same", old_path: "modified.ipynb", new_path: "modified.ipynb", },
  ])
  assert_eq(
    revisions.review(legacy).to_json(),
    revisions
    .review_files(@review.FileManifest::from_manifest(legacy))
    .to_json(),
  )
}
