package main

import rego.v1

# Team rule: every taggable resource carries these tags.
# Reads tags_all, so provider default_tags count.
required_tags := {"Owner", "CostCenter", "Environment"}

taggable := {
	"aws_s3_bucket",
	"aws_iam_role",
	"aws_security_group",
	"aws_instance",
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type in taggable
	some action in rc.change.actions
	action in {"create", "update"}
	tags := object.get(rc.change.after, "tags_all", {})
	present := {k | some k, _ in tags}
	missing := required_tags - present
	count(missing) > 0
	msg := sprintf("%s is missing required tags: %v", [rc.address, sort(missing)])
}
