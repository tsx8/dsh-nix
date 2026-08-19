"""Render a JSON tree as YAML, turning dsh-nix yamlTag markers into
`!!<tag>` scalars. The marker is a two-key object produced by Nix
(`__dshYamlTag`, `__dshYamlValue`); every other value is emitted by
PyYAML, which owns all quoting, escaping, and block-scalar edge cases.

PyYAML emits explicitly tagged scalars in single-quoted style
(`!!js 'expression'`); DeepSeek Harness parses that identically to the
unquoted form (verified against `dsh --dump-config`, which prints the
expression verbatim either way), so no custom dumper is needed.
"""

import json
import sys

import yaml

MARKER_TAG = "__dshYamlTag"
MARKER_VALUE = "__dshYamlValue"


class TaggedScalar(str):
    """A tagged YAML scalar; rendered as `!!<tag> <text>`."""

    def __new__(cls, tag, value):
        obj = str.__new__(cls, value)
        obj.tag = tag
        return obj


def tagged_representer(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:" + data.tag, str(data))


yaml.SafeDumper.add_multi_representer(TaggedScalar, tagged_representer)


def transform(value):
    if (
        isinstance(value, dict)
        and len(value) == 2
        and MARKER_TAG in value
        and MARKER_VALUE in value
    ):
        return TaggedScalar(value[MARKER_TAG], value[MARKER_VALUE])
    if isinstance(value, dict):
        return {key: transform(child) for key, child in value.items()}
    if isinstance(value, list):
        return [transform(child) for child in value]
    return value


def main():
    data = json.load(sys.stdin)
    sys.stdout.write(
        yaml.dump(
            transform(data),
            Dumper=yaml.SafeDumper,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
            width=2**31 - 1,  # never fold plain scalars; block scalars keep their shape
        )
    )


if __name__ == "__main__":
    main()
