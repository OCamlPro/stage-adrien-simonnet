module Pointer = Set.Make(Int)

type t = Pointer.t

let singleton (i: int) = Pointer.singleton i

let is_singleton set = Pointer.cardinal set = 1

let get_singleton set = Pointer.min_elt set

let join = Pointer.union

let to_list = Pointer.elements