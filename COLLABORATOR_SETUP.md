# Adding Collaborators to GeoWake Repository

This guide explains how to add collaborators to the GeoWake repository with the appropriate access levels.

## ⚠️ Important Note

**Adding collaborators cannot be done through code changes.** This requires repository owner/admin privileges through GitHub's interface or API.

## Steps to Add a Collaborator

### Via GitHub Web Interface (Recommended)

1. **Navigate to Repository Settings**
   - Go to https://github.com/Raed2180416/GeoWake
   - Click on **Settings** (you must be the repository owner or have admin access)

2. **Access Collaborators Section**
   - In the left sidebar, click on **Collaborators and teams**
   - You may need to confirm your password

3. **Add Collaborator**
   - Click the **Add people** button
   - Search for the GitHub username: `Anirudha-Belligundu`
   - Or use the direct profile: https://github.com/Anirudha-Belligundu

4. **Set Permission Level**
   - Select **Admin** or **Maintain** for complete access
   - Click **Add [username] to this repository**

5. **Wait for Acceptance**
   - The collaborator will receive an email invitation
   - They must accept the invitation to gain access

### Access Levels Explained

- **Read**: Can view and clone the repository
- **Triage**: Can manage issues and pull requests
- **Write**: Can push to the repository
- **Maintain**: Can manage the repository without access to sensitive settings
- **Admin**: Full access including settings, webhooks, and managing other collaborators

**For "complete access" as requested, select Admin level.**

### Via GitHub CLI (Alternative)

If you have GitHub CLI installed:

```bash
# Add collaborator with admin permission
gh api repos/Raed2180416/GeoWake/collaborators/Anirudha-Belligundu \
  --method PUT \
  -f permission=admin
```

### Via GitHub API (Advanced)

Using curl or similar tool:

```bash
curl -X PUT \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/Raed2180416/GeoWake/collaborators/Anirudha-Belligundu \
  -d '{"permission":"admin"}'
```

## Current Collaborator Configuration

This repository has been configured with:
- ✅ **CONTRIBUTORS.md** - Documents all contributors
- ✅ **CODEOWNERS** - Automatically requests reviews from designated code owners
- ✅ **README.md** - Updated to acknowledge contributors

## Next Steps

1. **Repository Owner Action Required**: Follow the steps above to add the collaborator via GitHub Settings
2. Once added, the collaborator will have full admin access to:
   - Manage repository settings
   - Merge pull requests
   - Manage issues and projects
   - Add/remove other collaborators
   - Configure webhooks and integrations

## Verification

After adding the collaborator, verify they have access by:
1. Asking them to visit https://github.com/Raed2180416/GeoWake/settings
2. They should be able to see and modify repository settings if admin access was granted

---

**Note**: The files created in this PR (CONTRIBUTORS.md, CODEOWNERS) document the intended collaborator structure but do not grant actual GitHub repository access. The repository owner must complete the steps above to grant access.
