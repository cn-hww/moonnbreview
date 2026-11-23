///|
fn same(a : Json?, b : Json?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => canonical(x) == canonical(y)
    _ => false
  }
}

///|
fn emit(
  items : Array[Change],
  kind : ChangeKind,
  cell_id : String?,
  path : String,
  before : Json?,
  after : Json?,
  suppressed_by~ : String? = None,
) -> Unit raise ReviewError {
  if same(before, after) {
    return
  }
  guard items.length() < 50000 else {
    raise Invalid("comparison exceeds 50000 changes; reduce input")
  }
  items.push({ kind, cell_id, path, before, after, suppressed_by, })
}

///|
fn field_diff(
  items : Array[Change],
  kind : ChangeKind,
  id : String?,
  path : String,
  a : Json?,
  b : Json?,
  suppressed_by~ : String? = None,
) -> Unit raise ReviewError {
  if same(a, b) {
    return
  }
  match (a, b) {
    (Some(Object(x)), Some(Object(y))) =>
      for key in union_keys(x, y) {
        field_diff(
          items,
          kind,
          id,
          pointer(path, key),
          x.get(key),
          y.get(key),
          suppressed_by~,
        )
      }
    _ => emit(items, kind, id, path, a, b, suppressed_by~)
  }
}

///|
fn union_keys(a : Map[String, Json], b : Map[String, Json]) -> Array[String] {
  let keys = a.keys().to_array()
  for key in b.keys() {
    if !a.contains(key) {
      keys.push(key)
    }
  }
  keys.sort()
  keys
}

///|
fn metadata_diff(
  items : Array[Change],
  id : String?,
  path : String,
  a : Json?,
  b : Json?,
  policy : Policy,
) -> Unit raise ReviewError {
  match (a, b) {
    (Some(Object(x)), Some(Object(y))) =>
      for key in union_keys(x, y) {
        let reason = if policy.metadata_keys.contains(key) {
          Some("metadata key: " + key)
        } else {
          None
        }
        field_diff(
          items,
          Metadata,
          id,
          pointer(path, key),
          x.get(key),
          y.get(key),
          suppressed_by=reason,
        )
      }
    _ => field_diff(items, Metadata, id, path, a, b)
  }
}

///|
fn count_diff(
  items : Array[Change],
  id : String?,
  path : String,
  a : Json?,
  b : Json?,
  policy : Policy,
) -> Unit raise ReviewError {
  let reason = if policy.counts {
    Some("ignore_execution_counts")
  } else {
    None
  }
  emit(items, ExecutionCount, id, path, a, b, suppressed_by=reason)
}

///|
fn outputs_diff(
  items : Array[Change],
  id : String?,
  a : Json?,
  b : Json?,
  policy : Policy,
) -> Unit raise ReviewError {
  match (a, b) {
    (Some(Array(x)), Some(Array(y))) if x.length() == y.length() =>
      for i in 0..<x.length() {
        let path = "/outputs/" + i.to_string()
        let old = object(x[i])
        let new = object(y[i])
        if old.get("output_type") != new.get("output_type") {
          emit(items, Output, id, path, Some(x[i]), Some(y[i]))
          continue
        }
        let standard_fields = match old.get("output_type") {
          Some(String("stream")) => ["output_type", "name", "text"]
          Some(String("display_data")) => ["output_type", "data", "metadata"]
          Some(String("execute_result")) =>
            ["output_type", "data", "metadata", "execution_count"]
          Some(String("error")) =>
            ["output_type", "ename", "evalue", "traceback"]
          _ => []
        }
        for key in union_keys(old, new) {
          if key == "execution_count" &&
            old.get("output_type") == Some(Json("execute_result")) {
            count_diff(
              items,
              id,
              pointer(path, key),
              old.get(key),
              new.get(key),
              policy,
            )
          } else if key == "metadata" &&
            old.get("output_type")
            is Some(String("display_data" | "execute_result")) {
            metadata_diff(
              items,
              id,
              pointer(path, key),
              old.get(key),
              new.get(key),
              policy,
            )
          } else {
            let kind = if standard_fields.contains(key) {
              Output
            } else {
              Extension
            }
            field_diff(
              items,
              kind,
              id,
              pointer(path, key),
              old.get(key),
              new.get(key),
            )
          }
        }
      }
    _ => emit(items, Output, id, "/outputs", a, b)
  }
}

///|
/// Compare by stable ID. Insertions do not masquerade as moves of later cells.
/// Retained-cell reordering is one complete old/new relative-order witness.
pub fn compare(
  old : Document,
  new : Document,
  policy~ : Policy = Policy::{ counts: false, metadata_keys: [], },
) -> Comparison raise ReviewError {
  let a = object(checked_json(old.to_string()))
  let b = object(checked_json(new.to_string()))
  guard a["cells"] is Array(ac) && b["cells"] is Array(bc) else {
    raise Invalid("missing cells")
  }
  let ai : Map[String, Json] = Map([])
  let bi : Map[String, Json] = Map([])
  let ao : Array[String] = []
  let bo : Array[String] = []
  for (cells, index, order) in [(ac, ai, ao), (bc, bi, bo)] {
    for cell in cells {
      let f = object(cell)
      guard f.get("id") is Some(String(id)) else {
        raise Invalid("missing cell ID")
      }
      index[id] = cell
      order.push(id)
    }
  }
  let items : Array[Change] = []
  let retained_old = ao.filter(id => bi.contains(id))
  let retained_new = bo.filter(id => ai.contains(id))
  emit(
    items,
    Order,
    None,
    "/cells",
    Some(Json(retained_old)),
    Some(Json(retained_new)),
  )
  for key in union_keys(a, b) {
    if key == "cells" {
      continue
    }
    if key == "metadata" {
      metadata_diff(items, None, "/metadata", a.get(key), b.get(key), policy)
    } else {
      field_diff(
        items,
        Extension,
        None,
        pointer("", key),
        a.get(key),
        b.get(key),
      )
    }
  }
  let ids = ai.keys().to_array()
  for id in bi.keys() {
    if !ai.contains(id) {
      ids.push(id)
    }
  }
  ids.sort()
  for id in ids {
    let av = ai.get(id)
    let bv = bi.get(id)
    guard av is Some(x) && bv is Some(y) else {
      emit(items, Structure, Some(id), "", av, bv)
      continue
    }
    let x = object(x)
    let y = object(y)
    if x.get("cell_type") != y.get("cell_type") {
      emit(items, Structure, Some(id), "", av, bv)
      continue
    }
    let code = x.get("cell_type") == Some(Json("code"))
    let prose = x.get("cell_type") is Some(String("markdown" | "raw"))
    for key in union_keys(x, y) {
      let path = pointer("", key)
      if key == "metadata" {
        metadata_diff(items, Some(id), path, x.get(key), y.get(key), policy)
      } else if code && key == "execution_count" {
        count_diff(items, Some(id), path, x.get(key), y.get(key), policy)
      } else if code && key == "outputs" {
        outputs_diff(items, Some(id), x.get(key), y.get(key), policy)
      } else {
        let kind = if key == "source" && (code || prose) {
          Source
        } else if key == "attachments" && prose {
          Attachment
        } else {
          Extension
        }
        field_diff(items, kind, Some(id), path, x.get(key), y.get(key))
      }
    }
  }
  { old, new, policy, items, }
}
