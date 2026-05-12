package compliance.container_security

import data.compliance.utils

# --- DENY rules (must pass for compliance) ---

# CIS 4.1: Container runs as non-root user
default deny_non_root_user := false
deny_non_root_user if {
	utils.is_root_user(input.Config.User)
}
non_root_user_msg := "CIS 4.1: Container must run as a non-root user"

# CIS 4.6: HEALTHCHECK instruction should be configured
default deny_healthcheck := false
deny_healthcheck if {
	input.Config.Healthcheck == null
}
healthcheck_msg := "CIS 4.6: HEALTHCHECK instruction should be configured"

# Privileged mode check
default deny_privileged := false
deny_privileged if {
	input.HostConfig.Privileged == true
}
privileged_msg := "Container should not run in privileged mode"

# Dangerous capabilities check
dangerous_caps := {"SYS_ADMIN", "NET_ADMIN", "SYS_MODULE", "SYS_RAWIO",
	"SYS_PTRACE", "SYS_BOOT", "SYS_TIME", "NET_RAW", "AUDIT_CONTROL"}

default deny_dangerous_caps := false
deny_dangerous_caps if {
	cap := input.HostConfig.CapAdd[_]
	dangerous_caps[cap]
}
dangerous_caps_msg := "Container should not be granted dangerous capabilities"

# Aggregate violations
violations contains msg if {
	deny_non_root_user
	msg := non_root_user_msg
}
violations contains msg if {
	deny_healthcheck
	msg := healthcheck_msg
}
violations contains msg if {
	deny_privileged
	msg := privileged_msg
}
violations contains msg if {
	deny_dangerous_caps
	msg := dangerous_caps_msg
}

# Overall pass/fail (deny rules only)
pass if {
	count(violations) == 0
}

# --- WARN rules (advisory, not blocking) ---

# Read-only root filesystem check (advisory — CI images may write)
default warn_read_write_fs := false
warn_read_write_fs if {
	input.HostConfig.ReadonlyRootfs == false
}
warn_read_write_fs if {
	input.HostConfig.ReadonlyRootfs == null
}
read_write_fs_warn := "ADVISORY: Container root filesystem should be read-only for production"

# CapDrop check — warn if ALL capabilities not dropped
default warn_no_cap_drop := false
warn_no_cap_drop if {
	not "ALL" in input.HostConfig.CapDrop
}
no_cap_drop_warn := "ADVISORY: All capabilities should be dropped with --cap-drop=ALL for production"

# no-new-privileges check
default warn_no_new_privs := false
warn_no_new_privs if {
	not "no-new-privileges" in input.HostConfig.SecurityOpt
	not "no-new-privileges=true" in input.HostConfig.SecurityOpt
}
no_new_privs_warn := "ADVISORY: --security-opt=no-new-privileges should be set for production"

# tmpfs mount check
default warn_no_tmpfs := false
warn_no_tmpfs if {
	count(input.HostConfig.Tmpfs) == 0
}
no_tmpfs_warn := "ADVISORY: /tmp, /var/tmp, /dev/shm should be mounted as tmpfs for production"

# Aggregate warnings
warnings contains msg if {
	warn_read_write_fs
	msg := read_write_fs_warn
}
warnings contains msg if {
	warn_no_cap_drop
	msg := no_cap_drop_warn
}
warnings contains msg if {
	warn_no_new_privs
	msg := no_new_privs_warn
}
warnings contains msg if {
	warn_no_tmpfs
	msg := no_tmpfs_warn
}
