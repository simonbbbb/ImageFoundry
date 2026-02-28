#!/usr/bin/env python3

"""
Selective build script to reduce GitHub Actions usage
Allows building only specific images based on changes or selection
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime

def get_changed_files():
    """Get list of changed files compared to main branch"""
    try:
        result = subprocess.run(
            ['git', 'diff', '--name-only', 'origin/main...HEAD'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip().split('\n') if result.stdout.strip() else []
    except subprocess.CalledProcessError:
        return []

def determine_affected_images(changed_files):
    """Determine which base images need rebuilding based on changed files"""
    affected = set()
    
    for file in changed_files:
        if file.startswith('configs/image-foundry.yaml'):
            # Config changed - rebuild all
            affected.update(['ubuntu-24.04', 'ubuntu-22.04', 'alpine-3.20'])
        elif file.startswith('templates/dockerfile-template.tmpl'):
            # Template changed - rebuild all
            affected.update(['ubuntu-24.04', 'ubuntu-22.04', 'alpine-3.20'])
        elif file.startswith('templates/base/ubuntu-24.04.Dockerfile'):
            affected.add('ubuntu-24.04')
        elif file.startswith('templates/base/ubuntu-22.04.Dockerfile'):
            affected.add('ubuntu-22.04')
        elif file.startswith('templates/base/alpine-3.20.Dockerfile'):
            affected.add('alpine-3.20')
        elif file.startswith('compliance/'):
            # Compliance policies changed - rebuild all
            affected.update(['ubuntu-24.04', 'ubuntu-22.04', 'alpine-3.20'])
        elif file.startswith('.github/workflows/'):
            # Workflows changed - rebuild all
            affected.update(['ubuntu-24.04', 'ubuntu-22.04', 'alpine-3.20'])
    
    return list(affected)

def read_config():
    """Read configuration to check what's enabled"""
    config_file = Path('configs/image-foundry.yaml')
    if not config_file.exists():
        return {}
    
    import yaml
    with open(config_file, 'r') as f:
        return yaml.safe_load(f)

def calculate_build_priority(images, config):
    """Calculate build priority based on usage and dependencies"""
    tools = config.get('tools', {})
    
    # Priority factors
    priorities = {}
    for img in images:
        priority = 0
        
        # Base images have higher priority
        if img == 'ubuntu-24.04':
            priority += 10
        elif img == 'ubuntu-22.04':
            priority += 8
        elif img == 'alpine-3.20':
            priority += 6
        
        # Check if essential tools are enabled
        if tools.get('languages', {}).get('go', {}).get('install', False):
            priority += 5
        if tools.get('security', {}).get('trivy', {}).get('install', False):
            priority += 4
        if tools.get('devops', {}).get('docker', {}).get('install', False):
            priority += 3
        
        priorities[img] = priority
    
    # Sort by priority (highest first)
    return sorted(images, key=lambda x: priorities.get(x, 0), reverse=True)

def generate_build_matrix(images, max_parallel=2):
    """Generate build matrix with limited parallelism"""
    # Group images by priority
    high_priority = []
    medium_priority = []
    low_priority = []
    
    config = read_config()
    prioritized = calculate_build_priority(images, config)
    
    # Split into priority groups
    if len(prioritized) >= 3:
        high_priority = prioritized[:1]
        medium_priority = prioritized[1:2]
        low_priority = prioritized[2:]
    elif len(prioritized) == 2:
        high_priority = prioritized[:1]
        medium_priority = prioritized[1:]
    else:
        high_priority = prioritized
    
    matrix = {
        'include': []
    }
    
    # Add high priority (build both architectures)
    for img in high_priority:
        matrix['include'].append({
            'base': img,
            'arch': 'amd64',
            'platform': 'linux/amd64',
            'priority': 'high'
        })
        matrix['include'].append({
            'base': img,
            'arch': 'arm64',
            'platform': 'linux/arm64',
            'priority': 'high'
        })
    
    # Add medium priority (amd64 only to save resources)
    for img in medium_priority:
        matrix['include'].append({
            'base': img,
            'arch': 'amd64',
            'platform': 'linux/amd64',
            'priority': 'medium'
        })
    
    # Add low priority (amd64 only)
    for img in low_priority:
        matrix['include'].append({
            'base': img,
            'arch': 'amd64',
            'platform': 'linux/amd64',
            'priority': 'low'
        })
    
    return matrix

def should_skip_build(base, config):
    """Check if a build can be skipped"""
    # Skip if no tools are enabled
    tools = config.get('tools', {})
    
    has_enabled_tools = (
        tools.get('languages', {}).get('go', {}).get('install', False) or
        tools.get('security', {}).get('trivy', {}).get('install', False) or
        tools.get('devops', {}).get('docker', {}).get('install', False) or
        tools.get('compliance', {}).get('enabled', False)
    )
    
    return not has_enabled_tools

def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Selective build helper')
    parser.add_argument('--mode', choices=['changed', 'config', 'all', 'select'], 
                       default='changed', help='Build mode')
    parser.add_argument('--images', nargs='+', 
                       choices=['ubuntu-24.04', 'ubuntu-22.04', 'alpine-3.20'],
                       help='Specific images to build (for select mode)')
    parser.add_argument('--max-parallel', type=int, default=2,
                       help='Maximum parallel builds')
    parser.add_argument('--output', help='Output file for build matrix')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be built without building')
    
    args = parser.parse_args()
    
    config = read_config()
    
    if args.mode == 'changed':
        # Build only images affected by changes
        changed_files = get_changed_files()
        if not changed_files:
            print('{"images": [], "reason": "no_changes"}')
            return
        
        affected = determine_affected_images(changed_files)
        print(f"[INFO] Changed files: {len(changed_files)}")
        print(f"[INFO] Affected images: {affected}")
        
        # Filter out builds that can be skipped
        images_to_build = []
        for img in affected:
            if not should_skip_build(img, config):
                images_to_build.append(img)
            else:
                print(f"[INFO] Skipping {img} - no enabled tools")
        
    elif args.mode == 'config':
        # Build based on configuration changes
        images_to_build = ['ubuntu-24.04', 'ubuntu-22.04', 'alpine-3.20']
        # Filter by enabled tools
        images_to_build = [img for img in images_to_build if not should_skip_build(img, config)]
        
    elif args.mode == 'all':
        # Build all images
        images_to_build = ['ubuntu-24.04', 'ubuntu-22.04', 'alpine-3.20']
        
    elif args.mode == 'select':
        # Build specific images
        images_to_build = args.images or []
    
    if not images_to_build:
        print('{"images": [], "reason": "no_images"}')
        return
    
    # Generate build matrix
    matrix = generate_build_matrix(images_to_build, args.max_parallel)
    
    if args.output:
        # Write matrix to file
        with open(args.output, 'w') as f:
            json.dump(matrix, f, indent=2)
        print(f"[INFO] Build matrix written to {args.output}")
    else:
        # Output matrix for GitHub Actions
        print(json.dumps(matrix))
    
    if args.dry_run:
        print(f"[DRY RUN] Would build: {images_to_build}")
        print(f"[DRY RUN] Matrix: {len(matrix['include'])} jobs")

if __name__ == '__main__':
    main()
