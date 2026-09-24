import json
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

def load_schema(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def iter_events(path):
    with Path(path).open(encoding="utf-8") as stream:
        for line_number, line in enumerate(stream, 1):
            if line.strip():
                yield line_number, json.loads(line)

def validate_file(schema_path, events_path):
    validator = Draft202012Validator(load_schema(schema_path), format_checker=FormatChecker())
    events = []
    for line_number, event in iter_events(events_path):
        errors = sorted(validator.iter_errors(event), key=lambda value: list(value.path))
        if errors:
            raise ValueError(f"line {line_number}: {errors[0].message}")
        events.append(event)
    if not events:
        raise ValueError("event file is empty")
    return events
