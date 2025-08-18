# GitHub Actions Security Best Practices

Critical memory: Always use commit SHAs instead of version tags for GitHub Actions.

## Security Requirement

**ALWAYS use commit SHAs instead of version tags** for all GitHub Actions in workflows.

### Format
```yaml
# Correct - use commit SHA with version comment
- uses: actions/checkout@08eba0b27e820071cde6df949e0beb9ba4906955 # v4

# Incorrect - never use version tags directly
- uses: actions/checkout@v4
```

## Security Benefits

1. **Immutable references**: Commit SHAs cannot be changed or moved
2. **Supply chain security**: Prevents tag hijacking and malicious updates
3. **Reproducible builds**: Exact same action code always used
4. **Audit trail**: Clear version tracking with proper documentation

## Finding Commit SHAs

For any GitHub Action version, find the commit SHA by:

1. Navigate to the action's GitHub repository
2. Go to Releases page
3. Click on the specific version tag (e.g., v4, v1.2.3)
4. Copy the commit SHA from the release page
5. Use full SHA, not abbreviated version

## Comment Requirements

**ALWAYS include version comment** after the commit SHA:

```yaml
- uses: owner/action@<FULL_COMMIT_SHA> # <ORIGINAL_VERSION>
```

Examples:
```yaml
- uses: actions/checkout@08eba0b27e820071cde6df949e0beb9ba4906955 # v4
- uses: actions/setup-node@b39b52d1213e96004bfcb1c61a8a6fa8ab84f3e8 # v4.0.1
```

## Maintenance Process

When updating GitHub Actions:

1. **Check for new releases** on action's GitHub repository
2. **Find new commit SHA** from release page
3. **Update workflow file** with new SHA
4. **Update comment** with correct version number
5. **Test thoroughly** before merging

## Current Sentry Lua Project SHAs

Reference SHAs used in this project (update when versions change):

- `actions/checkout@08eba0b27e820071cde6df949e0beb9ba4906955 # v4`
- `ilammy/msvc-dev-cmd@0b201ec74fa43914dc39ae48a89fd1d8cb592756 # v1`
- `leafo/gh-actions-lua@35bcb06abec04ec87df82e08caa84d545348536e # v10`
- `leafo/gh-actions-luarocks@e65774a6386cb4f24e293dca7fc4ff89165b64c5 # v4`
- `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4`
- `codecov/codecov-action@b9fd7d16f6d7d1b5d2bec1a2887e65ceed900238 # v4`
- `codecov/test-results-action@47f89e9acb64b76debcd5ea40642d25a4adced9f # v1`

## Validation

Before merging workflow changes:

- [ ] All actions use full commit SHAs (not abbreviated)
- [ ] All SHAs have correct version comments
- [ ] No version tags (like @v4) remain in workflow
- [ ] Comments match actual release versions
- [ ] Workflow passes CI tests

This prevents supply chain attacks and ensures reproducible, secure CI/CD pipelines.