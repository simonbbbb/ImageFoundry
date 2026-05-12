#!/usr/bin/env python3
"""
Generate Dockerfiles from template and configuration.

Processes the Go-template-style Dockerfile template with a proper
stack-based conditional evaluator. Handles nested {{- if }}, {{- else }},
{{- end }}, {{- range }}, and variable substitution.
"""

import re
import sys
from pathlib import Path
from datetime import datetime, timezone

import yaml


PROJECT_ROOT = Path(__file__).resolve().parent.parent
CONFIG_FILE = PROJECT_ROOT / "configs" / "image-foundry.yaml"
TEMPLATE_FILE = PROJECT_ROOT / "templates" / "dockerfile-template.tmpl"
OUTPUT_DIR = PROJECT_ROOT / "templates" / "base"

BASE_IMAGE_MAP = {
    "ubuntu-24.04": "ubuntu:24.04",
    "ubuntu-22.04": "ubuntu:22.04",
    "alpine-3.20": "alpine:3.20",
}


def load_config():
    with open(CONFIG_FILE) as f:
        return yaml.safe_load(f)


def get_git_revision():
    try:
        import subprocess
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        return ""


BASE_PACKAGES = {
    "ubuntu-24.04": {"ca-certificates", "curl", "wget", "gnupg", "jq", "git"},
    "ubuntu-22.04": {"ca-certificates", "curl", "wget", "gnupg", "jq", "git"},
    "alpine-3.20": {"ca-certificates", "curl", "wget", "jq", "git", "bash"},
}


def consolidate_packages(packages, base):
    """Generate a single consolidated RUN command for packages, excluding
    packages already installed in the base stage."""
    if not packages:
        return ""
    base_pkgs = BASE_PACKAGES.get(base, set())
    filtered = [p for p in packages if p not in base_pkgs]
    if not filtered:
        return ""
    if base in ("ubuntu-24.04", "ubuntu-22.04"):
        pkgs = " ".join(filtered)
        return f"RUN apt-get update && apt-get install -y --no-install-recommends {pkgs} && rm -rf /var/lib/apt/lists/* && apt-get clean"
    # Alpine
    pkgs = " ".join(filtered)
    return f"RUN apk add --no-cache {pkgs}"


def cosign_version(security_tools):
    """Return pinned cosign version, or empty for latest."""
    v = security_tools.get("cosign", {}).get("version", "")
    if v == "latest":
        return ""
    return v


def read_variables(config, base):
    """Extract all template variables from config."""
    tools = config.get("tools", {})
    languages = tools.get("languages", {})
    security_tools = tools.get("security", {})
    devops = tools.get("devops", {})
    security = config.get("security", {})

    go = languages.get("go", {})
    nodejs = languages.get("nodejs", {})
    python_lang = languages.get("python", {})

    return {
        "Base": base,
        "BaseImage": BASE_IMAGE_MAP[base],
        "Arch": "amd64",
        "Version": config.get("version", "0.1.0"),
        "Revision": get_git_revision(),
        "GoVersion": go.get("version", "1.26.0"),
        "NodeVersion": nodejs.get("version", "24"),
        "PythonVersion": python_lang.get("version", "3.14"),
        "KubectlVersion": devops.get("kubectl", {}).get("version", "1.35.1"),
        "HelmVersion": devops.get("helm", {}).get("version", "3.19.5"),
        "TerraformVersion": devops.get("terraform", {}).get("version", "1.14.6"),
        "CosignVersion": cosign_version(security_tools),
        "InstallNodeJS": str(nodejs.get("install", False)).lower(),
        "InstallPython": str(python_lang.get("install", False)).lower(),
        "InstallTrivy": str(security_tools.get("trivy", {}).get("install", False)).lower(),
        "InstallCosign": str(security_tools.get("cosign", {}).get("install", False)).lower(),
        "InstallSyft": str(security_tools.get("syft", {}).get("install", False)).lower(),
        "InstallCompliance": str(security.get("compliance", {}).get("enabled", False)).lower(),
        "InstallDocker": str(devops.get("docker", {}).get("install", False)).lower(),
        "InstallKubectl": str(devops.get("kubectl", {}).get("install", False)).lower(),
        "InstallHelm": str(devops.get("helm", {}).get("install", False)).lower(),
        "InstallTerraform": str(devops.get("terraform", {}).get("install", False)).lower(),
        "Timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "AdditionalPackages": tools.get("packages", []),
        "PackagesRun": consolidate_packages(tools.get("packages", []), base),
    }


def eval_condition(expr, vars):
    """Evaluate a Go-template condition expression."""
    expr = expr.strip()

    for prefix in [r"\.", r"\$\."]:
        m = re.match(r"^eq\s+" + prefix + r"(\w+)\s+(.+)$", expr)
        if m:
            values = re.findall(r'"([^"]*)"', m.group(2))
            return str(vars.get(m.group(1), "")) in values

        m = re.match(r"^" + prefix + r"(\w+)$", expr)
        if m:
            return str(vars.get(m.group(1), "false")).lower() == "true"

    return True


def process_template(template_path, vars):
    """Process template with stack-based conditional evaluation."""
    with open(template_path) as f:
        lines = f.readlines()

    output = []
    # Main processing stack: (active_bool, cond_result_bool)
    stack = []

    # Range bookkeeping
    in_range = False
    range_depth = 0
    range_items = []
    range_body = []

    for line in lines:
        stripped = line.strip()

        # --- Range start ---
        if re.match(r"\{\{-\s*range\s+\.AdditionalPackages\s*\}\}", stripped):
            in_range = True
            range_depth = 0
            range_items = list(vars.get("AdditionalPackages", []))
            range_body = []
            continue

        # --- Inside range ---
        if in_range:
            if re.match(r"\{\{-\s*if\b", stripped):
                range_depth += 1
                range_body.append(line)
                continue
            if re.match(r"\{\{-\s*else\s*\}\}", stripped):
                range_body.append(line)
                continue
            if re.match(r"\{\{-\s*end\s*\}\}", stripped):
                if range_depth > 0:
                    range_depth -= 1
                    range_body.append(line)
                    continue
                # End of range: expand the body for each item
                for item in range_items:
                    rstack = []
                    for rline in range_body:
                        rs = rline.strip()
                        mr = re.match(r"\{\{-\s*if\s+(.+?)\s*\}\}", rs)
                        if mr:
                            cond = eval_condition(mr.group(1), vars)
                            pa = all(s[0] for s in rstack)
                            rstack.append((pa and cond, cond))
                            continue
                        if re.match(r"\{\{-\s*else\s*\}\}", rs):
                            if rstack:
                                oa, oc = rstack.pop()
                                pa = all(s[0] for s in rstack)
                                rstack.append((pa and not oc, not oc))
                            continue
                        if re.match(r"\{\{-\s*end\s*\}\}", rs):
                            if rstack:
                                rstack.pop()
                            continue
                        if all(s[0] for s in rstack):
                            out = rline.replace("{{ . }}", item)
                            out = out.replace("{{$}}", item)
                            out = re.sub(
                                r"\{\{\s*\.(\w+)\s*\}\}",
                                lambda m: str(vars.get(m.group(1), m.group(0))),
                                out,
                            )
                            output.append(out)
                in_range = False
                range_items = []
                range_body = []
                continue
            # Regular line inside range body
            range_body.append(line)
            continue

        # ---- Main processing (not in range) ----

        # If
        mr = re.match(r"\{\{-\s*if\s+(.+?)\s*\}\}", stripped)
        if mr:
            cond = eval_condition(mr.group(1), vars)
            active = all(s[0] for s in stack) and cond
            stack.append((active, cond))
            continue

        # Else
        if re.match(r"\{\{-\s*else\s*\}\}", stripped):
            if stack:
                old_a, old_c = stack.pop()
                pa = all(s[0] for s in stack)
                stack.append((pa and not old_c, not old_c))
            continue

        # End
        if re.match(r"\{\{-\s*end\s*\}\}", stripped):
            if stack:
                stack.pop()
            continue

        # Variable substitution
        processed = line
        processed = re.sub(
            r"\{\{\s*\.(\w+)\s*\}\}",
            lambda m: str(vars.get(m.group(1), m.group(0))),
            processed,
        )
        processed = processed.replace("{{ . }}", "")
        processed = processed.replace("{{$}}", "")

        # Output if all parent conditions active
        if all(s[0] for s in stack):
            output.append(processed)

    return "".join(output)


def validate(content, base):
    issues = []
    if "FROM" not in content:
        issues.append("Missing FROM instruction")
    if "FROM base AS final" not in content:
        issues.append("Missing final stage")
    if content.count("FROM") < 2:
        issues.append("Expected multi-stage build")
    if content.strip() == "":
        issues.append("Empty output")
    return issues


def main():
    bases = sys.argv[1:] if len(sys.argv) > 1 else list(BASE_IMAGE_MAP.keys())

    config = load_config()

    for base in bases:
        print(f"[INFO] Processing {base}...")
        vars_dict = read_variables(config, base)
        content = process_template(TEMPLATE_FILE, vars_dict)

        out = OUTPUT_DIR / f"{base}.Dockerfile"
        with open(out, "w") as f:
            f.write(content)
        print(f"[INFO] Generated: {out}")

        issues = validate(content, base)
        if issues:
            for issue in issues:
                print(f"  [WARN] {issue}")
        else:
            print(f"[INFO] Validation passed")

    print("[INFO] Done!")


if __name__ == "__main__":
    main()
