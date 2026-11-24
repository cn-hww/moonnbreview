///|
let sample_before =
  #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[{"id":"a","cell_type":"markdown","metadata":{},"source":"before"}]}

///|
let sample_after =
  #|{"nbformat":4,"nbformat_minor":5,"metadata":{},"cells":[{"id":"a","cell_type":"markdown","metadata":{},"source":"after"}]}

///|
async fn cleanup(dir : String) -> Unit nocancel {
  @async.protect_from_cancel(() => {
    // Git creates read-only loose objects on Windows. Clear only this fixture's
    // attributes before removing the freshly allocated temporary repository.
    if @env.get_env_var("OS") == Some("Windows_NT") {
      let root = @fs.realpath(dir).replace_all(old="/", new="\\")
      let result = @shell.Cmd("attrib.exe", [
        "-R",
        root + "\\.git\\objects\\*",
        "/S",
      ]).output()
      result.check()
    }
    @fs.rmdir(dir, recursive=true)
  })
}

///|
async fn run_git(dir : String, args : Array[String]) -> String {
  let argv = [
    "-c", "user.name=cn-hww", "-c", "user.email=292744651+cn-hww@users.noreply.github.com",
    "-c", "commit.gpgsign=false", "-c", "core.autocrlf=false",
  ]
  for arg in args {
    argv.push(arg)
  }
  let result = @shell.Cmd("git", argv, cwd=dir).output()
  result.check()
  result.stdout()
}

///|
async fn setup_repo(dir : String, path : String) -> Unit {
  ignore(run_git(dir, ["init", "--quiet"]))
  @fs.write_file(dir + "/.gitattributes", "* -text\n")
  @fs.write_file(dir + "/" + path, sample_before)
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "fixture before"]))
  @fs.write_file(dir + "/" + path, sample_after)
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "fixture after"]))
}

///|
async fn refused(dir : String, revision : String, path : String) -> Bool {
  try {
    ignore(@git.Snapshot::load(dir, revision, path))
    false
  } catch {
    _ => true
  }
}

///|
async test "committed snapshots compare, replay and retain resolved identities" {
  let dir = @fs.tmpdir(prefix="nbreview-git-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  let old = @git.Snapshot::load(dir, "HEAD~1", "lesson.ipynb")
  let new = @git.Snapshot::load(dir, "HEAD", "lesson.ipynb")
  assert_eq(new.commit(), run_git(dir, ["rev-parse", "HEAD"]).trim().to_owned())
  assert_eq(new.path(), "lesson.ipynb")
  assert_false(old.commit() == new.commit())
  let c = @review.compare(old.document(), new.document())
  assert_eq(c.changes().length(), 1)
  assert_eq(c.changes()[0].kind, @review.Source)
  assert_eq(
    @review.Comparison::from_bundle(c.to_bundle()).to_json(),
    c.to_json(),
  )
  assert_true(c.to_markdown().contains("after"))
}

///|
async test "reading committed blobs preserves dirty worktree index and HEAD" {
  let dir = @fs.tmpdir(prefix="nbreview-git-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  @fs.write_file(dir + "/lesson.ipynb", "staged invalid notebook")
  ignore(run_git(dir, ["add", "--all"]))
  @fs.write_file(dir + "/lesson.ipynb", "unstaged invalid notebook")
  let status = run_git(dir, ["status", "--porcelain=v1"])
  let index = @fs.read_file(dir + "/.git/index").binary()
  let head = run_git(dir, ["rev-parse", "HEAD"])
  let a = @git.Snapshot::load(dir, "HEAD~1", "lesson.ipynb")
  let b = @git.Snapshot::load(dir, "HEAD", "lesson.ipynb")
  assert_false(@review.compare(a.document(), b.document()).passes())
  assert_eq(
    @fs.read_file(dir + "/lesson.ipynb").text(),
    "unstaged invalid notebook",
  )
  assert_eq(@fs.read_file(dir + "/.git/index").binary(), index)
  assert_eq(run_git(dir, ["status", "--porcelain=v1"]), status)
  assert_eq(run_git(dir, ["rev-parse", "HEAD"]), head)
}

///|
async test "literal spaces Unicode wildcard and shell characters name one file" {
  let dir = @fs.tmpdir(prefix="nbreview-git-")
  defer cleanup(dir)
  let path = "课程 [1] $(review).ipynb"
  setup_repo(dir, path)
  let s = @git.Snapshot::load(dir, "HEAD", path)
  assert_eq(s.path(), path)
  assert_true(s.document().to_string().contains("after"))
  assert_true(refused(dir, "HEAD", "*.ipynb"))
}

///|
async test "invalid paths revisions missing files and directories refuse then recover" {
  let dir = @fs.tmpdir(prefix="nbreview-git-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  for
    path in [
      "",
      "/lesson.ipynb",
      "../lesson.ipynb",
      "./lesson.ipynb",
      "a//b",
      "a\\b",
      "C:/x",
      "x\u0000",
      "x\n",
      "missing.ipynb",
      "x".repeat(4097),
    ] {
    assert_true(refused(dir, "HEAD", path))
  }
  for
    rev in [
      "",
      "--help",
      "missing-ref",
      "HEAD:lesson.ipynb",
      "HEAD\n",
      "x".repeat(1025),
    ] {
    assert_true(refused(dir, rev, "lesson.ipynb"))
  }
  @fs.mkdir(dir + "/nested")
  @fs.write_file(dir + "/nested/a.ipynb", sample_before)
  ignore(run_git(dir, ["add", "--all"]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "nested fixture"]))
  assert_true(refused(dir, "HEAD", "nested"))
  // A caller inside a subdirectory still supplies a repository-root path.
  let s = @git.Snapshot::load(dir + "/nested", "HEAD", "nested/a.ipynb")
  assert_true(s.document().to_string().contains("before"))
}

///|
async test "symlink entries invalid UTF8 and unsupported notebook bytes never disappear" {
  let dir = @fs.tmpdir(prefix="nbreview-git-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  // Construct a committed symlink entry without requiring OS symlink privileges.
  let blob = run_git(dir, ["rev-parse", "HEAD:lesson.ipynb"]).trim().to_owned()
  ignore(
    run_git(dir, [
      "update-index",
      "--add",
      "--cacheinfo",
      "120000," + blob + ",link.ipynb",
    ]),
  )
  @fs.write_file(dir + "/invalid.ipynb", b"\xff")
  @fs.write_file(dir + "/unsupported.ipynb", "{\"nbformat\":3}")
  @fs.write_file(dir + "/large.ipynb", "x".repeat(6000001))
  ignore(
    run_git(dir, [
      "add", "--", "invalid.ipynb", "unsupported.ipynb", "large.ipynb",
    ]),
  )
  ignore(run_git(dir, ["commit", "--quiet", "-m", "invalid fixtures"]))
  for
    path in ["link.ipynb", "invalid.ipynb", "unsupported.ipynb", "large.ipynb"] {
    assert_true(refused(dir, "HEAD", path))
  }
  ignore(@git.Snapshot::load(dir, "HEAD", "lesson.ipynb"))
}

///|
async test "explicit old and new paths preserve identities through notebook renames" {
  let dir = @fs.tmpdir(prefix="nbreview-git-")
  defer cleanup(dir)
  setup_repo(dir, "lesson.ipynb")
  let renamed = "改名 [1] $(review).ipynb"
  ignore(run_git(dir, ["mv", "--", "lesson.ipynb", renamed]))
  ignore(run_git(dir, ["commit", "--quiet", "-m", "rename fixture"]))
  let old = @git.Snapshot::load(dir, "HEAD~2", "lesson.ipynb")
  let new = @git.Snapshot::load(dir, "HEAD", renamed)
  assert_eq(old.path(), "lesson.ipynb")
  assert_eq(new.path(), renamed)
  let c = @review.compare(old.document(), new.document())
  assert_eq(c.changes().length(), 1)
  assert_eq(c.changes()[0].kind, @review.Source)
  assert_eq(c.changes()[0].cell_id, Some("a"))
  assert_true(refused(dir, "HEAD", "lesson.ipynb"))
  let before_rename = @git.Snapshot::load(dir, "HEAD~1", "lesson.ipynb")
  assert_true(
    @review.compare(before_rename.document(), new.document()).passes(),
  )
  assert_eq(
    @review.Comparison::from_bundle(c.to_bundle()).to_json(),
    c.to_json(),
  )
}
