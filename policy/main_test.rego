package main

import rego.v1

change_of(type, after) := {"address": sprintf("%s.t", [type]), "type": type, "change": {"actions": ["create"], "after": after}}

test_wildcard_action_denied if {
	doc := json.marshal({"Statement": [{"Effect": "Allow", "Action": "s3:*", "Resource": "*"}]})
	count(deny) > 0 with input as {"resource_changes": [change_of("aws_iam_role_policy", {"policy": doc})]}
}

test_scoped_action_allowed if {
	doc := json.marshal({"Statement": [{"Effect": "Allow", "Action": ["s3:GetObject"], "Resource": "arn:aws:s3:::b/*"}]})
	count(deny) == 0 with input as {"resource_changes": [change_of("aws_iam_role_policy", {"policy": doc})]}
}

test_missing_tags_denied if {
	count(deny) > 0 with input as {"resource_changes": [change_of("aws_instance", {"tags_all": {"Owner": "ahmed"}})]}
}

test_all_tags_allowed if {
	tags := {"Owner": "ahmed", "CostCenter": "dsai", "Environment": "dev"}
	count(deny) == 0 with input as {"resource_changes": [change_of("aws_instance", {"tags_all": tags})]}
}

test_public_block_off_denied if {
	after := {"block_public_acls": false, "block_public_policy": true, "ignore_public_acls": true, "restrict_public_buckets": true}
	count(deny) > 0 with input as {"resource_changes": [change_of("aws_s3_bucket_public_access_block", after)]}
}

test_bucket_without_block_denied if {
	count(deny) > 0 with input as {"resource_changes": [change_of("aws_s3_bucket", {"tags_all": {"Owner": "a", "CostCenter": "b", "Environment": "c"}})]}
}
