---
inclusion: auto
name: aws-infrastructure
description: Apply when designing, reviewing, validating, deploying, or deleting AWS CDK, CloudFormation, IAM policies, AWS CLI infrastructure commands, or AWS resources.
---

# AWS Infrastructure Guidance

## Scope and Precedence

- Follow repository-local architecture, deployment, account, Region, naming, tagging, and retention policies.
- Verify resource and property behavior against the current AWS service, AWS CDK, and CloudFormation documentation.
- Do not invent organization-specific requirements that are not established by the repository or the user.

## Sensitive Information and Public Artifacts

- Do not publish credentials, tokens, customer data, private endpoints, non-public account identifiers, internal system or tool names, personal data, or sensitive topology in public artifacts or disclose them to unauthorized recipients.
- Use non-public identifiers only when the task requires them, and keep them out of examples, public descriptions, public tags, shared logs, and responses unless disclosure is explicitly authorized.
- Do not hard-code secrets. Use the project's approved Secrets Manager or Systems Manager Parameter Store integration where supported.
- Do not assume that `NoEcho` or a dynamic reference prevents a destination service from logging or exposing a value; review the complete data path.

## Live AWS Safety

- Start with read-only inspection and identify the affected accounts, Regions, stacks, and environments.
- Before changing AWS state, verify the active identity and target locally using the project's approved profile and `aws sts get-caller-identity` or an equivalent trusted mechanism. Do not copy the full identity response into public artifacts, shared logs, or responses unless required and authorized.
- Do not deploy, destroy, bootstrap, import, execute a change set, or otherwise mutate AWS resources without explicit authorization.
- Do not bypass deployment approval or safety controls merely to make an operation proceed.

## Validation and Review

- Run the repository's established synthesis, lint, validation, and test commands before proposing deployment.
- Review `cdk diff` or a CloudFormation change set before applying changes.
- Explicitly call out replacement, deletion, data-loss risk, permission broadening, public or cross-account exposure, network access changes, and material cost impact.
- For stateful resources, follow project-specific backup, retention, rollback, and removal policies.

## CDK, CloudFormation, and IAM

- Avoid fixed physical resource names unless stability or an external integration requires them.
- Preserve stable construct paths and logical IDs unless replacement effects are understood and intended.
- Apply least privilege to identities and resource policies; prefer established CDK grant methods and repository guardrails where appropriate.
- If wildcard permissions are required by an AWS API, scope them with available conditions and document the reason.
- Review trust policies, IAM capabilities, public access, cross-account access, and Security Group ingress carefully.

## Descriptions, Names, and Tags

- As a personal portability convention, write supported AWS-facing description fields in concise English.
- Treat English as a convention, not as a universal AWS language requirement.
- Use the exact property supported by the target resource and follow its documented length, character, update, and replacement constraints.
- Follow service-specific naming rules and the repository's tagging policy; do not invent a universal naming pattern or mandatory tag set.
