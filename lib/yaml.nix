# YAML value helpers for the dsh-nix Home Manager module.
#
# `pkgs.formats.yaml` serializes through JSON and cannot express tagged
# scalars. DeepSeek Harness compositions use exactly one such feature: `!!js`
# expressions, which Cordis' entry-list schema defines as single-line
# scalars. `yamlTag` marks a scalar with such a tag; `generate` serializes
# the value to JSON and renders it with a PyYAML-based emitter that turns
# the markers back into `!!<tag> <text>` (PyYAML quotes the text; DSH
# parses the quoted and unquoted forms identically). All YAML content
# therefore stays a plain Nix value; no Cordis/DSH schema is copied into
# this module.
{
  lib,
  pkgs,
}:

let
  yamlTag = tag: value: {
    __dshYamlTag = tag;
    __dshYamlValue = value;
  };

  isYamlTag =
    value:
    lib.isAttrs value
    && lib.length (lib.attrNames value) == 2
    && value ? __dshYamlTag
    && value ? __dshYamlValue;

  tagsIn =
    value:
    if isYamlTag value then
      [ value ]
    else if lib.isList value then
      lib.concatMap tagsIn value
    else if lib.isAttrs value then
      lib.concatMap tagsIn (lib.attrValues value)
    else
      [ ];

  validate =
    tag:
    if
      !(lib.isString tag.__dshYamlTag && builtins.match "^[A-Za-z0-9_]+$" tag.__dshYamlTag != null)
    then
      throw "dsh-nix.lib.yamlTag: the tag must be a non-empty alphanumeric/underscore string, got ${builtins.toJSON tag.__dshYamlTag}"
    else if
      !(
        lib.isString tag.__dshYamlValue
        && !lib.hasInfix "\n" tag.__dshYamlValue
        && !lib.hasInfix "\r" tag.__dshYamlValue
      )
    then
      throw "dsh-nix.lib.yamlTag: the value must be a single-line string, matching the `!!js` scalar form used by DeepSeek Harness"
    else
      tag;

  generate =
    name: value:
    let
      python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
    in
    pkgs.runCommand name
      {
        json = builtins.deepSeq (map validate (tagsIn value)) (builtins.toJSON value);
        nativeBuildInputs = [ python ];
      }
      ''
        python3 ${./dsh-yaml.py} <<< "$json" > "$out"
      '';
in
{
  inherit generate yamlTag;
}
