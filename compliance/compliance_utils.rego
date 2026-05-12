package compliance.utils

# Check if a string matches any pattern in a list
contains_any(s, patterns) if {
	patterns[_] == s
}

# Check if a value is in a list
in_list(value, lst) if {
	value == lst[_]
}

# Check if image tag is "latest"
is_latest_tag(tag) if {
	tag == "latest"
}

# Check if user is root (empty string or "0" or "root")
is_root_user(user) if {
	user == ""
}

is_root_user(user) if {
	user == "0"
}

is_root_user(user) if {
	user == "root"
}

