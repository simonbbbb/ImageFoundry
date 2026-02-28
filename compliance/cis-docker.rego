package cis_docker

# CIS Docker Benchmark 1.0.0 - Level 1
# Policy for checking Docker host configuration compliance

default allow = false

allow {
    # CIS 1.1.1: Ensure Docker version is up to date
    input.docker.version >= "24.0.0"
    
    # CIS 1.1.2: Ensure Docker daemon configuration file exists
    file_exists("/etc/docker/daemon.json")
    
    # CIS 1.1.3: Ensure Docker daemon configuration file permissions
    file_permissions("/etc/docker/daemon.json", "644")
    
    # CIS 1.1.4: Ensure Docker daemon service user
    input.docker.user == "root"
}

# Helper functions
file_exists(path) {
    input.files[path].exists == true
}

file_permissions(path, expected) {
    input.files[path].mode == expected
}

# CIS 4.1: Ensure images are scanned for vulnerabilities
deny[msg] {
    not input.image.scanned
    msg := "Container image has not been scanned for vulnerabilities"
}

# CIS 4.5: Ensure content trust is enabled
deny[msg] {
    not input.docker.content_trust_enabled
    msg := "Docker content trust is not enabled"
}

# CIS 5.1: Ensure runtime is configured
deny[msg] {
    input.container.privileged == true
    msg := "Container should not run in privileged mode"
}

deny[msg] {
    input.container.user == "root"
    msg := "Container should not run as root user"
}

deny[msg] {
    count(input.container.volumes) == 0
    msg := "Container should have read-only filesystem"
}
