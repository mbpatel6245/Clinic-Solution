# Automatic web deployment

Every push to `main` builds the Flutter web application and deploys the
contents of `build/web` to the cPanel document root for
`https://clinic.mobitab.co.in`.

The workflow uses a dedicated SSH key. Do not add the cPanel password or a
private key to this repository.

## One-time setup

1. Generate a deployment key on your computer:

   ```powershell
   ssh-keygen -t ed25519 -C "github-actions-clinic" -f "$env:USERPROFILE\.ssh\github_clinic_deploy"
   ```

   Leave the passphrase empty because GitHub Actions must use the key without
   interactive input. This key must be used only for this deployment.

2. In cPanel, open **SSH Access > Manage SSH Keys > Import Key**. Import the
   contents of `github_clinic_deploy.pub`, then select **Manage > Authorize**.

3. In the GitHub repository, open **Settings > Secrets and variables > Actions**
   and create these repository secrets:

   - `CPANEL_SSH_PRIVATE_KEY`: the complete contents of
     `github_clinic_deploy`, including its BEGIN and END lines.
   - `CPANEL_SSH_KNOWN_HOSTS`: the output of:

     ```powershell
     ssh-keyscan -p 22 sh016.hostgator.in
     ```

4. Commit and push the workflow to `main`. Follow the first deployment under
   the repository's **Actions** tab. You can also start it manually with
   **Run workflow**.

## Deployment target

- Host: `sh016.hostgator.in`
- SSH port: `22`
- User: `mobituvx`
- Server directory: `/home2/mobituvx/clinic/`

The deploy step synchronizes the generated site and removes obsolete generated
files. It preserves the server's `.well-known` directory and `.ftpquota` file.

## Rollback

Revert the problematic commit on `main`, or select an older commit and run the
workflow manually after temporarily creating a branch from that commit. A new
successful deployment replaces the generated production files with that build.
