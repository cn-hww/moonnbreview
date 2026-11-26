///|
/// Compare explicitly present/absent notebook files. Both absent is invalid.
/// Two present inputs preserve compare() behavior and v1 bytes. Addition/deletion
/// emits one unsuppressed Structure witness at the notebook root, carrying the
/// entire normalized document. No empty notebook is substituted for absence.
pub fn compare_files(
  old : Document?,
  new : Document?,
  policy~ : Policy = Policy::{ counts: false, metadata_keys: [], },
) -> Comparison raise ReviewError {
  match (old, new) {
    (Some(a), Some(b)) => compare(a, b, policy~)
    (None, None) =>
      raise Invalid("file comparison requires at least one present notebook")
    _ => {
      let before = match old {
        Some(doc) => Some(checked_json(doc.to_string()))
        None => None
      }
      let after = match new {
        Some(doc) => Some(checked_json(doc.to_string()))
        None => None
      }
      let items = []
      emit(items, Structure, None, "", before, after)
      { old, new, policy, items, }
    }
  }
}
