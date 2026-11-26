///|
#derive(Debug, Eq)
pub(all) suberror ExportError {
  Invalid(String)
}

///|
fn object(value : Json) -> Map[String, Json] raise {
  guard value is Object(fields) else { fail("expected internal batch object") }
  fields
}

///|
fn string(value : Json) -> String raise {
  guard value is String(text) else { fail("expected internal batch string") }
  text
}

///|
/// Project an immutable Notebook batch into JUnit XML: one unique ID per case,
/// blocked changes as failures, input/recorded failures as errors. Complete pair
/// evidence is retained in system-out and policy/gate configuration in properties.
/// Uses the existing JUnit codec for serialization/validation; no generic JUnit
/// model/import API is duplicated here. Refuses unrepresentable XML and >10M units.
pub fn render(batch : @review.BatchReview) -> String raise ExportError {
  try {
    let root = object(
      @json.parse(
        batch.to_json(),
        max_nesting_depth=80,
        preserve_number_repr=true,
      ),
    )
    guard root["results"] is Array(entries) else {
      fail("missing internal batch results")
    }
    let mut suite = @codec.JUnitElement::suite("Notebook review")
      .add_property("moonnbreview.policy", root["policy"].stringify())
      .add_property("moonnbreview.gate", root["gate"].stringify())
    for entry in entries {
      let fields = object(entry)
      let status = string(fields["status"])
      let mut testcase = @codec.JUnitElement::testcase(
          string(fields["id"]),
          classname=Some("moonnbreview"),
        )
        .with_attribute(
          "file",
          string(
            if fields["new"] is Null {
              fields["old"]
            } else {
              fields["new"]
            },
          ),
        )
        .with_output("system-out", entry.stringify())
      if status == "blocked" {
        testcase = testcase.with_results([
          @codec.JUnitElement::result(
            "failure",
            type_="NotebookGateBlocked",
            message="Active changes block the configured gate",
            body=fields["report"].stringify(),
          ),
        ])
      } else if status == "error" {
        let diagnostic = object(fields["diagnostic"])
        testcase = testcase.with_results([
          @codec.JUnitElement::result(
            "error",
            type_="NotebookReviewError",
            message=string(diagnostic["phase"]),
            body=fields["diagnostic"].stringify(),
          ),
        ])
      } else {
        guard status == "passed" else { fail("unknown internal batch status") }
      }
      suite = suite.append(@codec.Element(testcase))
    }
    @codec.JUnitDocument::new(root=suite)
    .with_statistics()
    .to_xml(max_units=10000000L)
  } catch {
    @codec.InputError::InvalidInput(message) =>
      raise Invalid(
        "JUnit export refused: " +
        message +
        "; full JSON evidence remains available",
      )
    @codec.InputError::Rejected(code, message) =>
      raise Invalid(
        "JUnit export refused: " +
        code +
        ": " +
        message +
        "; full JSON evidence remains available",
      )
    @codec.InputError::UnknownField(field) =>
      raise Invalid("JUnit export refused unknown field: " + field)
    e =>
      raise Invalid(
        "JUnit export refused: \{Repr(e)}; full JSON evidence remains available",
      )
  }
}
