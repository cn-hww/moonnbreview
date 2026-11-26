///|
async test "automatic Git discovery reviews add delete edit and skips unrelated unchanged files" {
  let dir = @fs.tmpdir(prefix="nbreview-discover-")
  defer cleanup(dir)
  setup_repo(dir, "edited.ipynb")
  @fs.write_file(dir + "/gone.ipynb", sample_before)
  @fs.write_file(dir + "/same.ipynb", sample_before)
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "discovery baseline"]))
  ignore(run_git(dir, ["rm", "--", "gone.ipynb"]))
  @fs.write_file(dir + "/课程 [1] $(review).ipynb", sample_after)
  @fs.write_file(dir + "/edited.ipynb", sample_before)
  @fs.write_file(dir + "/readme.txt", "unrelated")
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "discovery proposed"]))
  let refs = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  let plan = refs.discover()
  assert_eq(plan.pairs().length(), 3)
  assert_eq(plan.to_json(), refs.discover().to_json())
  assert_false(plan.to_json().contains("same.ipynb"))
  assert_false(plan.to_json().contains("readme.txt"))
  let b = refs.review_files(plan, retain_inputs=true)
  assert_eq(b.exit_code(), 1)
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
  ignore(run_git(dir, ["config", "diff.relative", "true"]))
  ignore(run_git(dir, ["config", "diff.external", "false"]))
  @fs.mkdir(dir + "/nested")
  assert_eq(
    @git.Revisions::resolve(dir + "/nested", "HEAD~1", "HEAD")
    .discover()
    .to_json(),
    plan.to_json(),
  )
  let head = run_git(dir, ["rev-parse", "HEAD"])
  let index = @fs.read_file(dir + "/.git/index").binary()
  @fs.write_file(dir + "/edited.ipynb", "dirty invalid notebook")
  let status = run_git(dir, ["status", "--porcelain=v1"])
  assert_eq(refs.discover().to_json(), plan.to_json())
  assert_eq(refs.review_files(plan).to_json(), b.to_json())
  assert_eq(@fs.read_file(dir + "/.git/index").binary(), index)
  assert_eq(run_git(dir, ["status", "--porcelain=v1"]), status)
  assert_eq(run_git(dir, ["rev-parse", "HEAD"]), head)
}

///|
async test "automatic discovery represents renamed and suffix-crossing paths without identity guessing" {
  let dir = @fs.tmpdir(prefix="nbreview-discover-")
  defer cleanup(dir)
  setup_repo(dir, "old.ipynb")
  @fs.write_file(dir + "/incoming.txt", sample_before)
  @fs.write_file(dir + "/outgoing.ipynb", sample_after)
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "rename baseline"]))
  ignore(run_git(dir, ["mv", "--", "old.ipynb", "renamed.ipynb"]))
  ignore(run_git(dir, ["mv", "--", "incoming.txt", "incoming.ipynb"]))
  ignore(run_git(dir, ["mv", "--", "outgoing.ipynb", "outgoing.txt"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "rename proposed"]))
  let refs = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  let plan = refs.discover()
  assert_eq(plan.pairs().length(), 4)
  assert_eq(plan.pairs().iter().filter(p => p.old_path is None).count(), 2)
  assert_eq(plan.pairs().iter().filter(p => p.new_path is None).count(), 2)
  assert_eq(refs.review_files(plan).exit_code(), 1)
  let explicit = @review.Manifest::new([
    { id: "rename", old_path: "old.ipynb", new_path: "renamed.ipynb", },
  ])
  assert_eq(refs.review(explicit).exit_code(), 0)
}

///|
async test "discovery remains pinned after refs advance and malformed new notebooks retain errors" {
  let dir = @fs.tmpdir(prefix="nbreview-discover-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  let refs = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  let before = refs.discover().to_json()
  @fs.write_file(dir + "/bad.ipynb", "{invalid")
  @fs.write_file(dir + "/good.ipynb", sample_before)
  ignore(run_git(dir, ["add", "--all"]))
  ignore(
    run_git(dir, ["commit", "--quiet", "-m", "advance with malformed addition"]),
  )
  assert_eq(refs.discover().to_json(), before)
  let latest = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  let plan = latest.discover()
  let b = latest.review_files(plan, retain_inputs=true)
  assert_eq(b.exit_code(), 2)
  assert_true(b.to_json().contains("parse_new"))
  assert_true(b.to_json().contains("\"status\":\"blocked\""))
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
  let empty = @git.Revisions::resolve(dir, "HEAD", "HEAD").discover()
  assert_eq(empty.pairs().length(), 0)
  assert_eq(latest.review_files(empty).exit_code(), 0)
}

///|
async test "discovered type changes and malformed UTF8 become errors instead of disappearing" {
  let dir = @fs.tmpdir(prefix="nbreview-discover-")
  defer cleanup(dir)
  setup_repo(dir, "typed.ipynb")
  let blob = run_git(dir, ["hash-object", "-w", "--", "typed.ipynb"])
    .trim()
    .to_owned()
  ignore(
    run_git(dir, [
      "update-index",
      "--add",
      "--cacheinfo",
      "120000," + blob + ",typed.ipynb",
    ]),
  )
  @fs.write_file(dir + "/invalid.ipynb", b"\xff")
  @fs.write_file(dir + "/good.ipynb", sample_before)
  ignore(run_git(dir, ["add", "--", "invalid.ipynb", "good.ipynb"]))
  ignore(
    run_git(dir, ["commit", "--quiet", "-m", "unsupported selected inputs"]),
  )
  let refs = @git.Revisions::resolve(dir, "HEAD~1", "HEAD")
  let plan = refs.discover()
  assert_eq(plan.pairs().length(), 3)
  let b = refs.review_files(plan, retain_inputs=true)
  assert_eq(b.exit_code(), 2)
  assert_true(b.to_json().contains("read_new"))
  assert_true(b.to_json().contains("\"status\":\"blocked\""))
  assert_eq(
    @review.BatchReview::from_bundle(b.to_bundle()).to_json(),
    b.to_json(),
  )
}
