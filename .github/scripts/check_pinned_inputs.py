"""Check the `with:` keys of every step action against its action.yml.

actionlint skips input validation for SHA-pinned actions, and since v2 it must
ignore every self-repository (`$/`) reference, so this fills both gaps. It reads
the steps of workflows (`jobs.<id>.steps`) and of composite actions
(`runs.steps` in an action.yml), and for each step `uses:`

  - `owner/repo[/path]@<sha>`  fetches action.yml at that SHA (anonymously from
                               raw.githubusercontent.com, falling back to
                               `gh api` with GH_TOKEN for private actions)
  - `$/path/to/action`         reads `path/to/action/action.yml` from this
                               checkout: `$/` resolves to the repository of the
                               file it appears in, at the running commit, so
                               it needs no pin. Run from the repository root.

and reports

  - UNKNOWN INPUT     a `with:` key the action does not declare
  - MISSING REQUIRED  a required input with no default that is not passed
  - NOT PINNED        a third-party step action not pinned to a full commit SHA
  - BAD SELF REF      a `$/` step reference carrying an `@ref` (not allowed)
  - FETCH FAILED      action.yml could not be read at that ref, or a `$/`
                      action has no action.yml in this checkout

Exit status is 1 if any of those is found. Deprecated inputs are only warned.

Out of scope: job-level `uses:` of reusable workflows (`$/` included),
workspace-relative (`./`) actions and `docker://` images. Step actions owned by
orion-digital-solutions may use a tag or branch (same policy as
.github/zizmor.yml); their inputs are still checked.

Usage: python check_pinned_inputs.py <workflow.yml | action.yml> [...]
"""
import functools
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

import yaml

SHA = re.compile(r"^[0-9a-f]{40}$")
OWN_ORG = "orion-digital-solutions"
SELF = "$/"


def _fetch_raw(owner_repo, path, ref):
    """Anonymous fetch from raw.githubusercontent.com.

    Used first because organisations with an IP allow list (e.g. aquasecurity,
    bridgecrewio) reject authenticated API calls from GitHub-hosted runner IPs
    with HTTP 403, while their public files stay readable anonymously.
    """
    url = f"https://raw.githubusercontent.com/{owner_repo}/{ref}/{path}"
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:  # noqa: S310 (fixed https host)
            return resp.read().decode("utf-8")
    except (urllib.error.URLError, TimeoutError) as exc:
        return exc


@functools.lru_cache(maxsize=None)
def action_inputs(owner_repo, subpath, ref):
    errors = []
    for name in ("action.yml", "action.yaml"):
        path = f"{subpath}/{name}" if subpath else name
        raw = _fetch_raw(owner_repo, path, ref)
        if isinstance(raw, str):
            return (yaml.safe_load(raw) or {}).get("inputs") or {}
        errors.append(f"raw: {raw}")
        # Fallback for private actions: the API with GH_TOKEN.
        r = subprocess.run(
            ["gh", "api", f"repos/{owner_repo}/contents/{path}?ref={ref}",
             "-H", "Accept: application/vnd.github.raw"],
            capture_output=True, text=True, encoding="utf-8")
        if r.returncode == 0:
            return (yaml.safe_load(r.stdout) or {}).get("inputs") or {}
        errors.append(r.stderr.strip())
    raise LookupError("; ".join(e for e in errors if e) or "no action.yml")


@functools.lru_cache(maxsize=None)
def local_action_inputs(subpath):
    """Inputs of a `$/` action, read from this checkout (cwd = repo root)."""
    for name in ("action.yml", "action.yaml"):
        path = os.path.join(subpath, name) if subpath else name
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as fh:
                return (yaml.safe_load(fh) or {}).get("inputs") or {}
    raise LookupError(f"no action.yml or action.yaml in ./{subpath} of this checkout")


def is_true(value):
    # action.yml authors write both `required: true` and `required: 'true'`.
    return str(value).strip().lower() == "true"


def step_lists(doc):
    """(location, steps) for each step list in a workflow or composite action."""
    for job_id, job in (doc.get("jobs") or {}).items():
        yield job_id, (job or {}).get("steps") or []
    runs = doc.get("runs") or {}
    if isinstance(runs, dict) and str(runs.get("using", "")).lower() == "composite":
        yield "runs.steps", runs.get("steps") or []


def resolve(uses):
    """Return (target, lookup) for a step `uses:`, or (problem label, None)."""
    if uses.startswith(SELF):
        if "@" in uses:
            return "BAD SELF REF", None
        return uses, functools.partial(local_action_inputs, uses[len(SELF):].strip("/"))
    if "@" not in uses:
        return "NOT PINNED", None
    target, ref = uses.split("@", 1)
    parts = target.split("/")
    owner_repo, sub = "/".join(parts[:2]), "/".join(parts[2:])
    if not SHA.match(ref) and parts[0].lower() != OWN_ORG:
        return "NOT PINNED", None
    return target, functools.partial(action_inputs, owner_repo, sub, ref)


def check_step(step, where):
    """Return (checked, problems) for one step."""
    uses = str(step.get("uses") or "")
    if not uses or uses.startswith(("./", "docker://")):
        return 0, 0
    target, lookup = resolve(uses)
    if lookup is None:
        print(f"{target} {where}: {uses}")
        return 0, 1
    try:
        ins = lookup()
    except LookupError as exc:
        print(f"FETCH FAILED {where}: {uses}: {exc}")
        return 0, 1
    return 1, check_inputs(ins, step.get("with") or {}, where, target)


def check_inputs(ins, given, where, target):
    """Print and count input problems of one step."""
    bad = 0
    for k in given:
        if k not in ins:
            print(f"UNKNOWN INPUT {where}: {target}: {k}")
            bad += 1
    for k, spec in ins.items():
        spec = spec or {}
        if is_true(spec.get("required")) and "default" not in spec and k not in given:
            print(f"MISSING REQUIRED {where}: {target}: {k}")
            bad += 1
        if k in given and spec.get("deprecationMessage"):
            print(f"DEPRECATED (warning) {where}: {target}: {k}")
    return bad


def main(files):
    bad = checked = 0
    for path in files:
        with open(path, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh) or {}
        for loc, steps in step_lists(doc):
            for step in steps:
                c, b = check_step(step or {}, f"{path}:{loc}")
                checked += c
                bad += b
    print(f"checked {checked} step actions, problems: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1:]))
