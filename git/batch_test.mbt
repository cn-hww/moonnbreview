///|
fn batch_manifest(pairs : Array[@review.ReviewPair]) -> @review.Manifest raise {
  @review.Manifest::new(pairs)
}

///|
async test "Git batch equals independent sources including same paths and retained replay" {
  let dir = @fs.tmpdir(prefix="nbreview-git-batch-")
  defer cleanup(dir)
  let path = "课程 [1] $(review).ipynb"
  setup_repo(dir, path)
  let revisions = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  assert_eq(
    revisions.old_commit(),
    run_git(dir, ["rev-parse", "HEAD~1"]).trim().to_owned(),
  )
  assert_eq(
    revisions.new_commit(),
    run_git(dir, ["rev-parse", "HEAD"]).trim().to_owned(),
  )
  let m = batch_manifest([{ id: "lesson", old_path: path, new_path: path, }])
  let expected = m.review_sides(
    _ => sample_before,
    _ => sample_after,
    retain_inputs=true,
  )
  let batch = revisions.review(m, retain_inputs=true)
  assert_eq(batch.to_json(), expected.to_json())
  assert_eq(batch.to_bundle(), expected.to_bundle())
  assert_eq(
    @review.BatchReview::from_bundle(batch.to_bundle()).to_json(),
    batch.to_json(),
  )
  assert_eq(batch.exit_code(), 1)
  let no_retention = revisions.review(m)
  assert_eq(no_retention.to_json(), batch.to_json())
  assert_true(
    try {
      ignore(no_retention.to_bundle())
      false
    } catch {
      _ => true
    },
  )
}

///|
async test "Git batch remains pinned after symbolic refs move and preserves dirty state" {
  let dir = @fs.tmpdir(prefix="nbreview-git-batch-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  let revisions = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  let old_id = revisions.old_commit()
  let new_id = revisions.new_commit()
  @fs.write_file(dir + "/lesson.ipynb", "invalid newer commit")
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "advance ref"]))
  @fs.write_file(dir + "/lesson.ipynb", "staged invalid")
  ignore(run_git(dir, ["add", "--all"]))
  @fs.write_file(dir + "/lesson.ipynb", "unstaged invalid")
  let head = run_git(dir, ["rev-parse", "HEAD"])
  let index = @fs.read_file(dir + "/.git/index").binary()
  let status = run_git(dir, ["status", "--porcelain=v1"])
  let m = batch_manifest([
    { id: "lesson", old_path: "lesson.ipynb", new_path: "lesson.ipynb", },
  ])
  assert_eq(revisions.review(m).exit_code(), 1)
  assert_eq(revisions.old_commit(), old_id)
  assert_eq(revisions.new_commit(), new_id)
  assert_eq(run_git(dir, ["rev-parse", "HEAD"]), head)
  assert_eq(run_git(dir, ["status", "--porcelain=v1"]), status)
  assert_eq(@fs.read_file(dir + "/.git/index").binary(), index)
  assert_eq(@fs.read_file(dir + "/lesson.ipynb").text(), "unstaged invalid")
}

///|
async test "Git batch keeps errors and later evidence across explicit renames" {
  let dir = @fs.tmpdir(prefix="nbreview-git-batch-")
  defer cleanup(dir)
  setup_repo(dir, "old.ipynb")
  ignore(run_git(dir, ["mv", "--", "old.ipynb", "新 [2].ipynb"]))
  @fs.write_file(dir + "/broken.ipynb", "{broken")
  ignore(run_git(dir, ["add", "--all"]))
  ignore(
    run_git(dir, ["commit", "--quiet", "-m", "rename and malformed input"]),
  )
  let m = batch_manifest([
    { id: "old-missing", old_path: "missing", new_path: "新 [2].ipynb", },
    { id: "new-missing", old_path: "old.ipynb", new_path: "missing", },
    { id: "new-invalid", old_path: "old.ipynb", new_path: "broken.ipynb", },
    { id: "invalid-path", old_path: "../old.ipynb", new_path: "新 [2].ipynb", },
    { id: "renamed", old_path: "old.ipynb", new_path: "新 [2].ipynb", },
  ])
  let b = @git.Revisions::resolve(dir, "HEAD~2", "HEAD").review(
    m,
    retain_inputs=true,
  )
  assert_eq(b.exit_code(), 2)
  assert_true(b.to_json().contains("parse_new"))
  assert_true(b.to_json().contains("read_old"))
  assert_true(b.to_json().contains("read_new"))
  assert_true(b.to_json().contains("\"status\":\"blocked\""))
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
}

///|
async test "Git batch applies gates without removing active comparison evidence" {
  let dir = @fs.tmpdir(prefix="nbreview-git-batch-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  let m = batch_manifest([
    { id: "lesson", old_path: "lesson.ipynb", new_path: "lesson.ipynb", },
  ])
  let revisions = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  let gate = @review.Gate::new(blocked=[@review.Output])
  let b = revisions.review(m, gate~, retain_inputs=true)
  assert_eq(b.exit_code(), 0)
  assert_true(b.to_json().contains("\"kind\":\"source\""))
  assert_eq(
    b.to_json(),
    m.review_sides(_ => sample_before, _ => sample_after, gate~).to_json(),
  )
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
}

///|
async test "Git batch invalid revisions refuse globally and empty manifests perform no blob reads" {
  let dir = @fs.tmpdir(prefix="nbreview-git-batch-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  for revision in ["--help", "missing-ref", "HEAD:lesson.ipynb"] {
    assert_true(
      try {
        ignore(@git.Revisions::resolve(dir, "HEAD", revision))
        false
      } catch {
        _ => true
      },
    )
  }
  let b = @git.Revisions::resolve(dir, "HEAD", "HEAD").review(
    batch_manifest([]),
    retain_inputs=true,
  )
  assert_eq(b.exit_code(), 0)
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
}
