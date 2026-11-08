package main

import rego.v1

# Team rule: no Allow statement with a wildcard action.
iam_policy_types := {"aws_iam_policy", "aws_iam_role_policy", "aws_iam_user_policy", "aws_iam_group_policy"}

as_list(x) := x if is_array(x)

as_list(x) := [x] if not is_array(x)

wildcard(a) if a == "*"

wildcard(a) if endswith(a, ":*")

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type in iam_policy_types
	doc := json.unmarshal(rc.change.after.policy)
	some st in as_list(doc.Statement)
	st.Effect == "Allow"
	some action in as_list(st.Action)
	wildcard(action)
	msg := sprintf("%s allows wildcard action %q", [rc.address, action])
}
