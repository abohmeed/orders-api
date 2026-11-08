package main

import rego.v1

# Team rule: no S3 bucket may be public.
public_flags := [
	"block_public_acls",
	"block_public_policy",
	"ignore_public_acls",
	"restrict_public_buckets",
]

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "aws_s3_bucket_public_access_block"
	some flag in public_flags
	rc.change.after[flag] != true
	msg := sprintf("%s must set %s = true", [rc.address, flag])
}

# Every planned bucket needs a public access block in the same plan.
deny contains msg if {
	buckets := [rc | rc := input.resource_changes[_]; rc.type == "aws_s3_bucket"; "create" in rc.change.actions]
	blocks := [rc | rc := input.resource_changes[_]; rc.type == "aws_s3_bucket_public_access_block"; "create" in rc.change.actions]
	count(blocks) < count(buckets)
	msg := sprintf("%d new bucket(s) but only %d public access block(s)", [count(buckets), count(blocks)])
}
