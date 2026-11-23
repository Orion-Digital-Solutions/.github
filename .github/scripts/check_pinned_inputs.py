"""Check the `with:` keys of every step action against its action.yml.

actionlint skips input validation for SHA-pinned actions, so this fills the gap:
for each step `uses: owner/repo[/path]@<sha>` it fetches action.yml at that SHA
(via `gh api`, so GH_TOKEN must be set) and reports

  - UNKNOWN INPUT     a `with:` key the action does not declare
  - MISSING REQUIRED  a required input with no default that is not passed
  - NOT PINNED        a third-party step action not pinned to a full commit SHA
  - FETCH FAILED      action.yml could not be read at that ref

Exit status is 1 if any of those is found. Deprecated inputs are only warned.

Out of scope: job-level `uses:` of reusable workflows, local (`./`) actions and
`docker://` images. Step actions owned by orion-digital-solutions may use a tag
or branch (same policy as .github/zizmor.yml); their inputs are still checked.

Usage: python check_pinned_inputs.py <workflow.yml> [...]
"""
import functools
import re
import subprocess
import sys

import yaml

SHA = re.compile(r"^[0-9a-f]{40}$")
OWN_ORG = "orion-digital-solutions"


@functools.lru_cache(maxsize=None)
def action_inputs(owner_repo, subpath, ref):
    errors = []
    for name in ("action.yml", "action.yaml"):
        path = f"{subpath}/{name}" if subpath else name
        r = subprocess.run(
            ["gh", "api", f"repos/{owner_repo}/contents/{path}?ref={ref}",
             "-H", "Accept: application/vnd.github.raw"],
            capture_output=True, text=True, encoding="utf-8")
        if r.returncode == 0:
            return (yaml.safe_load(r.stdout) or {}).get("inputs") or {}
        errors.append(r.stderr.strip())
    raise LookupError("; ".join(e for e in errors if e) or "no action.yml")


def is_true(value):
    # action.yml authors write both `required: true` and `required: 'true'`.
    return str(value).strip().lower() == "true"


def main(files):
    bad = checked = 0
    for wf in files:
        with open(wf, encoding="utf-8") as fh:
            doc = yaml.safe_load(fh) or {}
        for job_id, job in (doc.get("jobs") or {}).items():
            for step in (job or {}).get("steps") or []:
                uses = str(step.get("uses") or "")
                if not uses or uses.startswith(("./", "docker://")):
                    continue
                where = f"{wf}:{job_id}"
                if "@" not in uses:
                    print(f"NOT PINNED {where}: {uses}")
                    bad += 1
                    continue
                target, ref = uses.split("@", 1)
                parts = target.split("/")
                owner_repo, sub = "/".join(parts[:2]), "/".join(parts[2:])
                own = parts[0].lower() == OWN_ORG
                if not SHA.match(ref) and not own:
                    print(f"NOT PINNED {where}: {uses}")
                    bad += 1
                    continue
                try:
                    ins = action_inputs(owner_repo, sub, ref)
                except LookupError as exc:
                    print(f"FETCH FAILED {where}: {uses}: {exc}")
                    bad += 1
                    continue
                given = step.get("with") or {}
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
                checked += 1
    print(f"checked {checked} step actions, problems: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1:]))
