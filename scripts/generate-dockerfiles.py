#!/usr/bin/env python3

"""
Generate Dockerfiles from template and configuration
"""

import os
import sys
import yaml
from pathlib import Path
from datetime import datetime

def read_config(config_file):
    """Read configuration from YAML file"""
    with open(config_file, 'r') as f:
        return yaml.safe_load(f)

def read_template(template_file):
    """Read template file"""
    with open(template_file, 'r') as f:
        return f.read()

def process_template(template_content, config, base):
    """Process template with configuration"""
    
    # Base image mapping
    base_images = {
        'ubuntu-24.04': 'ubuntu:24.04',
        'ubuntu-22.04': 'ubuntu:22.04',
        'alpine-3.20': 'alpine:3.20'
    }
    
    # Extract values from config
    tools = config.get('tools', {})
    languages = tools.get('languages', {})
    security = tools.get('security', {})
    devops = tools.get('devops', {})
    compliance = config.get('compliance', {})
    
    # Template variables
    variables = {
        'Base': base,
        'BaseImage': base_images.get(base, f'{base}:latest'),
        'Arch': 'amd64',
        'GoVersion': languages.get('go', {}).get('version', '1.22.0'),
        'NodeVersion': languages.get('nodejs', {}).get('version', '20'),
        'PythonVersion': languages.get('python', {}).get('version', '3.12'),
        'KubectlVersion': devops.get('kubectl', {}).get('version', '1.29.0'),
        'HelmVersion': devops.get('helm', {}).get('version', '3.14.0'),
        'TerraformVersion': devops.get('terraform', {}).get('version', '1.7.0'),
        'InstallNodeJS': 'true' if languages.get('nodejs', {}).get('install', False) else 'false',
        'InstallPython': 'true' if languages.get('python', {}).get('install', False) else 'false',
        'InstallTrivy': 'true' if security.get('trivy', {}).get('install', False) else 'false',
        'InstallCosign': 'true' if security.get('cosign', {}).get('install', False) else 'false',
        'InstallSyft': 'true' if security.get('syft', {}).get('install', False) else 'false',
        'InstallDocker': 'true' if devops.get('docker', {}).get('install', False) else 'false',
        'InstallKubectl': 'true' if devops.get('kubectl', {}).get('install', False) else 'false',
        'InstallHelm': 'true' if devops.get('helm', {}).get('install', False) else 'false',
        'InstallTerraform': 'true' if devops.get('terraform', {}).get('install', False) else 'false',
        'InstallCompliance': 'true' if compliance.get('enabled', False) else 'false',
        'Timestamp': datetime.utcnow().isoformat() + 'Z',
        'AdditionalPackages': tools.get('packages', [])
    }
    
    import re
    
    # Process the template
    result = template_content
    
    # Replace simple variables first
    for key, value in variables.items():
        if key != 'AdditionalPackages':
            result = result.replace(f'{{{{ .{key} }}}}', str(value))
    
    # Process Ubuntu base conditionals
    if base in ['ubuntu-24.04', 'ubuntu-22.04']:
        # Keep Ubuntu blocks
        result = re.sub(
            r'{{- if eq \.Base "ubuntu-24\.04" "ubuntu-22\.04" }}\n(.*?)\n{{- end }}',
            r'\1',
            result,
            flags=re.DOTALL
        )
        result = re.sub(
            r'{{- if eq \$\.Base "ubuntu-24\.04" "ubuntu-22\.04" }}\n(.*?)\n{{- end }}',
            r'\1',
            result,
            flags=re.DOTALL
        )
        # Remove Alpine blocks
        result = re.sub(
            r'{{- if eq \.Base "alpine-3\.20" }}\n(.*?)\n{{- end }}',
            '',
            result,
            flags=re.DOTALL
        )
        result = re.sub(
            r'{{- if eq \$\.Base "alpine-3\.20" }}\n(.*?)\n{{- end }}',
            '',
            result,
            flags=re.DOTALL
        )
    elif base == 'alpine-3.20':
        # Keep Alpine blocks
        result = re.sub(
            r'{{- if eq \.Base "alpine-3\.20" }}\n(.*?)\n{{- end }}',
            r'\1',
            result,
            flags=re.DOTALL
        )
        result = re.sub(
            r'{{- if eq \$\.Base "alpine-3\.20" }}\n(.*?)\n{{- end }}',
            r'\1',
            result,
            flags=re.DOTALL
        )
        # Remove Ubuntu blocks
        result = re.sub(
            r'{{- if eq \.Base "ubuntu-24\.04" "ubuntu-22\.04" }}\n(.*?)\n{{- end }}',
            '',
            result,
            flags=re.DOTALL
        )
        result = re.sub(
            r'{{- if eq \$\.Base "ubuntu-24\.04" "ubuntu-22\.04" }}\n(.*?)\n{{- end }}',
            '',
            result,
            flags=re.DOTALL
        )
    
    # Process tool installation conditionals
    for tool_name, install_flag in variables.items():
        if tool_name.startswith('Install'):
            actual_tool = tool_name.replace('Install', '')
            if install_flag == 'true':
                # Keep the block
                result = re.sub(
                    f'{{{{- if \.{tool_name} }}}}\n(.*?)\n{{{{- end }}}}',
                    r'\1',
                    result,
                    flags=re.DOTALL
                )
            else:
                # Remove the block
                result = re.sub(
                    f'{{{{- if \.{tool_name} }}}}\n(.*?)\n{{{{- end }}}}',
                    '',
                    result,
                    flags=re.DOTALL
                )
    
    # Handle additional packages
    packages_content = []
    for pkg in variables['AdditionalPackages']:
        if base in ['ubuntu-24.04', 'ubuntu-22.04']:
            packages_content.append(f'RUN apt-get update && apt-get install -y {pkg} && rm -rf /var/lib/apt/lists/*')
        elif base == 'alpine-3.20':
            packages_content.append(f'RUN apk add --no-cache {pkg}')
    
    result = re.sub(
        r'{{- range \.AdditionalPackages }}\n(.*?)\n{{- end }}',
        '\n'.join(packages_content) if packages_content else '',
        result,
        flags=re.DOTALL
    )
    
    # Remove any remaining conditional markers
    result = re.sub(r'{{- if.*?}}\n?', '', result)
    result = re.sub(r'{{- end }}\n?', '', result)
    
    return result

def validate_dockerfile(dockerfile_path):
    """Validate generated Dockerfile"""
    with open(dockerfile_path, 'r') as f:
        content = f.read()
    
    issues = []
    
    # Check for required sections
    if 'FROM' not in content:
        issues.append("Missing FROM instruction")
    
    if 'FROM base AS final' not in content:
        issues.append("Missing final layer")
    
    # Check for syntax issues
    if content.count('FROM') < 2:
        issues.append("Expected multiple FROM instructions for multi-stage build")
    
    return issues

def main():
    """Main function"""
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    config_file = project_root / 'configs' / 'image-foundry.yaml'
    template_file = project_root / 'templates' / 'dockerfile-template.tmpl'
    
    # Parse arguments
    bases = []
    if len(sys.argv) > 1:
        bases = sys.argv[1:]
    else:
        bases = ['ubuntu-24.04', 'ubuntu-22.04', 'alpine-3.20']
    
    print(f"[INFO] Starting Dockerfile generation...")
    print(f"[INFO] Using config: {config_file}")
    print(f"[INFO] Using template: {template_file}")
    
    # Read configuration and template
    config = read_config(config_file)
    template_content = read_template(template_file)
    
    # Generate Dockerfiles
    for base in bases:
        print(f"[INFO] Processing {base}...")
        
        # Process template
        dockerfile_content = process_template(template_content, config, base)
        
        # Write Dockerfile
        output_file = project_root / 'templates' / 'base' / f'{base}.Dockerfile'
        with open(output_file, 'w') as f:
            f.write(dockerfile_content)
        
        print(f"[INFO] Generated: {output_file}")
        
        # Validate
        issues = validate_dockerfile(output_file)
        if issues:
            print(f"[WARN] Found {len(issues)} potential issues in {base}:")
            for issue in issues:
                print(f"  - {issue}")
        else:
            print(f"[INFO] Validation passed for {base}")
        
        print()
    
    print(f"[INFO] Dockerfile generation complete!")
    print(f"[INFO] Generated files:")
    for base in bases:
        print(f"  - templates/base/{base}.Dockerfile")

if __name__ == '__main__':
    main()
