package compliance.image_metadata

import data.compliance.utils

# Required OCI labels
required_labels := {
	"org.opencontainers.image.title",
	"org.opencontainers.image.description",
	"org.opencontainers.image.version",
	"org.opencontainers.image.created",
	"org.opencontainers.image.source",
	"org.opencontainers.image.authors",
	"org.opencontainers.image.url",
	"org.opencontainers.image.documentation",
	"org.opencontainers.image.licenses",
	"org.opencontainers.image.revision",
	"org.opencontainers.image.base.name",
}

# Check required labels exist
default deny_missing_labels := false
deny_missing_labels if {
	label := required_labels[_]
	not input.Config.Labels[label]
}
missing_labels_msg := "Required OCI labels are missing from the image"

# No "latest" tag in production
default deny_latest_tag := false
deny_latest_tag if {
	input.RepoTags != null
	tag := input.RepoTags[_]
	utils.is_latest_tag(trim_left(tag, " "))
}
latest_tag_msg := "Image should not use the 'latest' tag for production deployments"

# No secrets in environment variables
secret_patterns := {"PASSWORD", "PASSWD", "SECRET", "TOKEN", "API_KEY",
	"APIKEY", "PRIVATE_KEY", "ACCESS_KEY", "AUTH_TOKEN"}

default deny_secrets_in_env := false
deny_secrets_in_env if {
	env_var := input.Config.Env[_]
	pattern := secret_patterns[_]
	contains(upper(env_var), pattern)
}
secrets_in_env_msg := "Potential secrets found in environment variables"

# No empty or default passwords in environment
default deny_empty_passwords := false
deny_empty_passwords if {
	env_var := input.Config.Env[_]
	startswith(upper(env_var), "PASSWORD=")
}
empty_passwords_msg := "Password environment variables should not be empty or default"

# Aggregate all metadata violations
violations contains msg if {
	deny_missing_labels
	msg := missing_labels_msg
}
violations contains msg if {
	deny_latest_tag
	msg := latest_tag_msg
}
violations contains msg if {
	deny_secrets_in_env
	msg := secrets_in_env_msg
}
violations contains msg if {
	deny_empty_passwords
	msg := empty_passwords_msg
}

# Overall pass/fail
pass if {
	count(violations) == 0
}
