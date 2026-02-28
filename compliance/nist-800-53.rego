package nist_800_53

# NIST SP 800-53 Security Controls
# Policy for checking NIST compliance requirements

default allow = false

allow {
    # AC-1: Access Control Policy
    has_access_control_policy
    
    # AC-2: Account Management
    has_account_management
    
    # AC-3: Access Enforcement
    has_least_privilege
    
    # AU-1: Audit and Accountability Policy
    has_audit_policy
    
    # AU-2: Audit Events
    has_audit_events
    
    # CM-1: Configuration Management Policy
    has_config_management
    
    # CM-2: Baseline Configuration
    has_baseline_config
    
    # SC-1: System and Communications Protection Policy
    has_security_policy
    
    # SC-7: Boundary Protection
    has_boundary_protection
    
    # SC-12: Cryptographic Key Establishment and Management
    has_crypto_management
}

# Access Control Requirements
has_access_control_policy {
    input.access_control.policy_exists == true
    input.access_control.reviewed == true
}

has_account_management {
    input.accounts.managed == true
    input.accounts.unique_identifiers == true
    input.accounts.review_frequency <= 90
}

has_least_privilege {
    input.privilege.principle == "least_privilege"
    input.privilege.enforced == true
}

# Audit Requirements
has_audit_policy {
    input.audit.policy_exists == true
    input.audit.retention_period >= 90
}

has_audit_events {
    input.audit.events_enabled == true
    input.audit.log_types[_] == "authentication"
    input.audit.log_types[_] == "authorization"
    input.audit.log_types[_] == "system_changes"
}

# Configuration Management
has_config_management {
    input.config.management_enabled == true
    input.config.baseline_approved == true
    input.config.change_control == true
}

has_baseline_config {
    input.config.baseline_exists == true
    input.config.baseline_approved == true
    input.config.deviation_tracked == true
}

# Security Requirements
has_security_policy {
    input.security.policy_exists == true
    input.security.communication_protected == true
}

has_boundary_protection {
    input.network.firewall_enabled == true
    input.network.segmentation == true
    input.network.ingress_filtered == true
}

has_crypto_management {
    input.crypto.key_management == true
    input.crypto.encryption_at_rest == true
    input.crypto.encryption_in_transit == true
}

# Denials for non-compliance
deny[msg] {
    not has_access_control_policy
    msg := "AC-1: Access control policy is missing or not reviewed"
}

deny[msg] {
    not has_account_management
    msg := "AC-2: Account management controls are not implemented"
}

deny[msg] {
    not has_least_privilege
    msg := "AC-3: Least privilege principle is not enforced"
}

deny[msg] {
    not has_audit_policy
    msg := "AU-1: Audit policy is missing"
}

deny[msg] {
    not has_audit_events
    msg := "AU-2: Required audit events are not being logged"
}

deny[msg] {
    not has_config_management
    msg := "CM-1: Configuration management is not implemented"
}

deny[msg] {
    not has_boundary_protection
    msg := "SC-7: Network boundary protection is not implemented"
}

deny[msg] {
    not has_crypto_management
    msg := "SC-12: Cryptographic management is not implemented"
}
