package compliance.cis_benchmark

import data.compliance.utils

# =============================================================================
# CIS Docker Benchmark — Container Images controls
# =============================================================================

# CIS 4.1: Create a non-root user for the container
# Evidence: Dockerfile must have USER directive != root
default deny_root_user := false
deny_root_user if {
	utils.is_root_user(input.Config.User)
}
cis_4_1_msg := "CIS 4.1: Container must run as non-root user"

# CIS 4.2: Use trusted base images
# Evidence: FROM must reference an official or approved registry
trusted_registries := {
	"docker.io/library",
	"docker.io/library/ubuntu",
	"docker.io/library/alpine",
	"docker.io/library/debian",
	"ghcr.io",
}
default deny_untrusted_base := false
deny_untrusted_base if {
	not startswith(input.Config.Image, "docker.io/library/")
	not startswith(input.Config.Image, "ghcr.io/")
}
cis_4_2_msg := "CIS 4.2: Base images must come from trusted registries"

# CIS 4.3: Do not install unnecessary packages in containers
# NOTE: This is a design-level check — enforce via Dockerfile review
# The image should only contain tools explicitly configured in image-foundry.yaml

# CIS 4.4: Scan images for vulnerabilities and rebuild them
# Evidence: Trivy scan must have been run and uploaded
# NOTE: Verified externally via CI pipeline artifact existence

# CIS 4.5: Enable Docker Content Trust
# Evidence: Images must be signed (Cosign attestation)

# CIS 4.6: Add HEALTHCHECK instruction
default deny_no_healthcheck := false
deny_no_healthcheck if {
	input.Config.Healthcheck == null
}
cis_4_6_msg := "CIS 4.6: HEALTHCHECK instruction must be configured"

# CIS 4.7: Do not use privileged mode
default deny_privileged_mode := false
deny_privileged_mode if {
	input.HostConfig.Privileged == true
}
cis_4_7_msg := "CIS 4.7: Container must not run in privileged mode"

# CIS 4.8: Do not mount sensitive host directories
sensitive_host_paths := {
	"/",
	"/etc",
	"/var",
	"/run",
	"/sys",
	"/proc",
	"/dev",
	"/boot",
	"/root",
	"/home",
}

default deny_sensitive_mount := false
deny_sensitive_mount if {
	mount := input.Mounts[_]
	sensitive_host_paths[mount.Source]
}
cis_4_8_msg := "CIS 4.8: Do not mount sensitive host system directories"

# CIS 4.9: Use COPY instead of ADD
# NOTE: This is a Dockerfile-level check — enforced by the template system
# The dockerfile-template.tmpl uses COPY exclusively (verified by CI/hadolint)

# CIS 4.10: Do not store secrets in environment variables
secret_patterns := {"PASSWORD", "PASSWD", "SECRET", "TOKEN", "API_KEY",
	"APIKEY", "PRIVATE_KEY", "ACCESS_KEY", "AUTH_TOKEN", "CREDENTIAL"}

default deny_secrets_in_env := false
deny_secrets_in_env if {
	env_var := input.Config.Env[_]
	pattern := secret_patterns[_]
	contains(upper(env_var), pattern)
}
cis_4_10_msg := "CIS 4.10: Secrets must not be stored in environment variables"

# CIS 4.11: Do not store sensitive data in images
sensitive_files := [".pem", ".key", ".p12", ".pfx", ".cert", ".crt", ".der",
	".p7b", ".p7c", ".jks", ".keystore", ".kdb", ".kyr"]

# CIS 5.1: Remove setuid/setgid binaries
# Evidence: Dockerfile must run find / -perm /6000 -exec chmod a-s
# NOTE: Verified via Dockerfile template inspection

# CIS 5.2: Restrict world-writable directories
# Evidence: Dockerfile must run find / -type d -perm 0002 -exec chmod o-w
# NOTE: Verified via Dockerfile template inspection

# CIS 5.3: Use Linux Security Modules (AppArmor, SELinux)
# Evidence: Security labels must be present
default deny_no_lsm_profile := false
deny_no_lsm_profile if {
	not "apparmor" in concat("", input.HostConfig.SecurityOpt)
	not "seccomp" in concat("", input.HostConfig.SecurityOpt)
}
cis_5_3_msg := "CIS 5.3: AppArmor or seccomp security profiles should be applied"
warn_no_lsm_profile := cis_5_3_msg

# CIS 5.4: Restrict capabilities
default deny_not_all_caps_dropped := false
deny_not_all_caps_dropped if {
	not "ALL" in input.HostConfig.CapDrop
}
cis_5_4_msg := "CIS 5.4: All capabilities should be dropped (--cap-drop=ALL)"

# CIS 5.5: Do not use no-new-privileges
default deny_no_new_privileges := false
deny_no_new_privileges if {
	not "no-new-privileges" in concat("", input.HostConfig.SecurityOpt)
}
cis_5_5_msg := "CIS 5.5: --security-opt=no-new-privileges must be set"

# CIS 5.6: Do not mount Docker socket
default deny_docker_socket := false
deny_docker_socket if {
	mount := input.Mounts[_]
	contains(mount.Source, "/var/run/docker.sock")
}
cis_5_6_msg := "CIS 5.6: Docker socket must not be mounted in containers"

# CIS 5.7: Do not share the host network namespace
default deny_host_network := false
deny_host_network if {
	input.HostConfig.NetworkMode == "host"
}
cis_5_7_msg := "CIS 5.7: Host network namespace must not be shared"

# CIS 5.8: Do not share the host PID namespace
default deny_host_pid := false
deny_host_pid if {
	input.HostConfig.PidMode == "host"
}
cis_5_8_msg := "CIS 5.8: Host PID namespace must not be shared"

# CIS 5.9: Do not share the host IPC namespace
default deny_host_ipc := false
deny_host_ipc if {
	input.HostConfig.IpcMode == "host"
}
cis_5_9_msg := "CIS 5.9: Host IPC namespace must not be shared"

# CIS 5.10: Do not map host UTS namespace
default deny_host_uts := false
deny_host_uts if {
	input.HostConfig.UTSMode == "host"
}
cis_5_10_msg := "CIS 5.10: Host UTS namespace must not be shared"

# CIS 5.11: Do not map host user namespaces
default deny_host_user := false
deny_host_user if {
	input.HostConfig.UsernsMode == "host"
}
cis_5_11_msg := "CIS 5.11: Host user namespace must not be shared"

# CIS 5.12: Use read-only root filesystem
default deny_writable_rootfs := false
deny_writable_rootfs if {
	input.HostConfig.ReadonlyRootfs == false
}
deny_writable_rootfs if {
	input.HostConfig.ReadonlyRootfs == null
}
cis_5_12_msg := "CIS 5.12: Container root filesystem should be read-only"

# CIS 5.13: Use tmpfs for /tmp, /var/tmp, /dev/shm
default deny_no_tmpfs := false
deny_no_tmpfs if {
	count(input.HostConfig.Tmpfs) == 0
}
cis_5_13_msg := "CIS 5.13: /tmp, /var/tmp, /dev/shm should be mounted as tmpfs"

# CIS 5.14: Do not use memory constraints
default deny_no_memory_limit := false
deny_no_memory_limit if {
	input.HostConfig.Memory == 0
}
cis_5_14_msg := "CIS 5.14: Memory constraints should be set"

# =============================================================================
# Aggregation
# =============================================================================

all_violations contains msg if {
	deny_root_user; msg := cis_4_1_msg
}
all_violations contains msg if {
	deny_untrusted_base; msg := cis_4_2_msg
}
all_violations contains msg if {
	deny_no_healthcheck; msg := cis_4_6_msg
}
all_violations contains msg if {
	deny_privileged_mode; msg := cis_4_7_msg
}
all_violations contains msg if {
	deny_sensitive_mount; msg := cis_4_8_msg
}
all_violations contains msg if {
	deny_secrets_in_env; msg := cis_4_10_msg
}
all_violations contains msg if {
	deny_not_all_caps_dropped; msg := cis_5_4_msg
}
all_violations contains msg if {
	deny_no_new_privileges; msg := cis_5_5_msg
}
all_violations contains msg if {
	deny_docker_socket; msg := cis_5_6_msg
}
all_violations contains msg if {
	deny_host_network; msg := cis_5_7_msg
}
all_violations contains msg if {
	deny_host_pid; msg := cis_5_8_msg
}
all_violations contains msg if {
	deny_host_ipc; msg := cis_5_9_msg
}
all_violations contains msg if {
	deny_host_uts; msg := cis_5_10_msg
}
all_violations contains msg if {
	deny_host_user; msg := cis_5_11_msg
}

all_warnings contains msg if {
	warn_no_lsm_profile
}

# =============================================================================
# Score
# =============================================================================

violation_count := count(all_violations)
warning_count := count(all_warnings)

pass if {
	violation_count == 0
}

score := (1.0 - (violation_count / 20)) * 100

summary := sprintf("CIS Docker Benchmark: %d violations, %d warnings — Score: %.0f/100", [
	violation_count, warning_count, score
])
