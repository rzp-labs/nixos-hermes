{ inputs, ... }:

let
  emptyCategory = { };
in
{
  imports = [ (inputs.den.namespace "lab" false) ];

  lab = {
    roles = emptyCategory;
    features = emptyCategory;
    workloads = emptyCategory;
    hardware = emptyCategory;
    platform = emptyCategory;
    users = emptyCategory;
    quirks = emptyCategory;
  };
}
