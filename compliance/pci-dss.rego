package pci_dss

# PCI DSS Requirements
# Policy for checking Payment Card Industry Data Security Standard compliance

default allow = false

allow {
    # Requirement 1: Install and maintain network security controls
    has_firewall_configuration
    
    # Requirement 2: Apply secure configuration to all system components
    has_secure_configuration
    
    # Requirement 3: Protect stored cardholder data
    has_data_protection
    
    # Requirement 4: Protect cardholder data with strong cryptography
    has_encryption
    
    # Requirement 5: Protect all systems against malicious software
    has_malware_protection
    
    # Requirement 6: Develop secure systems and software
    has_secure_development
    
    # Requirement 7: Restrict access to cardholder data
    has_access_control
    
    # Requirement 8: Identify users and authenticate access
    has_authentication
    
    # Requirement 9: Restrict physical access to cardholder data
    has_physical_security
    
    # Requirement 10: Log and monitor all access to network resources
    has_logging_monitoring
    
    # Requirement 11: Regularly test security systems and processes
    has_security_testing
    
    # Requirement 12: Support information security with organizational policies
    has_security_policies
}

# Network Security Controls
has_firewall_configuration {
    input.network.firewall_enabled == true
    input.network.unnecessary_services_disabled == true
    input.network.insecure_protocols_blocked == true
}

# Secure Configuration
has_secure_configuration {
    input.system.hardened == true
    input.system.default_passwords_changed == true
    input.system.patch_management == true
}

# Data Protection
has_data_protection {
    input.data.minimization == true
    input.data.retention_limited == true
    input.data.disposal_secure == true
}

# Encryption
has_encryption {
    input.encryption.at_rest == true
    input.encryption.in_transit == true
    input.encryption.key_management == true
}

# Malware Protection
has_malware_protection {
    input.security.antivirus_enabled == true
    input.security.antivirus_updated == true
    input.security.file_scanning == true
}

# Secure Development
has_secure_development {
    input.development.secure_coding == true
    input.development.code_review == true
    input.development.vulnerability_testing == true
}

# Access Control
has_access_control {
    input.access.need_to_know == true
    input.access.least_privilege == true
    input.access.review_frequency <= 90
}

# Authentication
has_authentication {
    input.authentication.unique_identifiers == true
    input.authentication.strong_auth == true
    input.authentication.session_timeout == true
}

# Physical Security
has_physical_security {
    input.physical.access_restricted == true
    input.physical.video_surveillance == true
    input.physical.media_destruction == true
}

# Logging and Monitoring
has_logging_monitoring {
    input.logging.enabled == true
    input.logging.all_access == true
    input.logging.retention >= 365
    input.logging.alerting == true
}

# Security Testing
has_security_testing {
    input.testing.penetration_testing == true
    input.testing.vulnerability_scanning == true
    input.testing.frequency_quarterly == true
}

# Security Policies
has_security_policies {
    input.policies.security_policy == true
    input.policies.risk_assessment == true
    input.policies.incident_response == true
}

# PCI DSS Specific Denials
deny[msg] {
    not has_firewall_configuration
    msg := "PCI-DSS Req 1: Network security controls are not properly configured"
}

deny[msg] {
    not has_data_protection
    msg := "PCI-DSS Req 3: Cardholder data protection measures are not implemented"
}

deny[msg] {
    not has_encryption
    msg := "PCI-DSS Req 4: Strong cryptography is not implemented"
}

deny[msg] {
    not has_access_control
    msg := "PCI-DSS Req 7: Access to cardholder data is not properly restricted"
}

deny[msg] {
    not has_authentication
    msg := "PCI-DSS Req 8: User authentication controls are not implemented"
}

deny[msg] {
    not has_logging_monitoring
    msg := "PCI-DSS Req 10: Access logging and monitoring is not implemented"
}
