# Automatic deployments

Every push to `main` builds the Flutter web application and deploys the
contents of `build/web` to the cPanel document root for
`https://clinic.mobitab.co.in`.

The workflow uses a dedicated SSH key. Do not add the cPanel password or a
private key to this repository.

## One-time setup

1. In cPanel, open **Security > SSH Access > Manage SSH Keys > Generate a New
   Key**. Create a dedicated deployment key named `github_clinic_deploy`, use
   RSA with a 4096-bit size, and protect it with a strong passphrase.

2. Under **Public Keys**, select **Manage > Authorize** for the new key. Under
   **Private Keys**, select **View/Download** and copy the OpenSSH/PEM private
   key, including its BEGIN and END lines. Do not use a PuTTY `.ppk` value.

3. In the GitHub repository, open **Settings > Secrets and variables > Actions**
   and create these repository secrets:

   - `CPANEL_SSH_PRIVATE_KEY`: the complete downloaded private key.
   - `CPANEL_SSH_KEY_PASSPHRASE`: the passphrase used when generating the key.
   - `CPANEL_SSH_KNOWN_HOSTS`: the verified output of:

     ```powershell
     ssh-keyscan -p 22 sh016.hostgator.in
     ```

   The workflow loads the encrypted key into a temporary SSH agent. Secret
   values are not written to the repository.

4. Push to `main` or open **Actions > Deploy clinic web app > Run workflow**.
   Follow the run until the deployment and production verification both pass.

## Deployment target

- Host: `sh016.hostgator.in`
- SSH port: `22`
- User: `mobituvx`
- Domain: `clinic.mobitab.co.in`
- Server directory: detected over SFTP by matching the deployed production
  JavaScript bundle, then restricted to known locations inside the account
  home directory.

The deploy step uploads the generated site recursively over SFTP. It does not
require cPanel shell access and does not alter the server's `.well-known`
directory or `.ftpquota` file.
The workflow publishes `deployment.txt` containing the deployed commit SHA and
reads it back through the production domain, so updating an unrelated server
directory can no longer report a successful deployment.

## Android Firebase App Distribution

Every push to `main` also builds a release APK, runs the Flutter tests, and
uploads the APK to Firebase App Distribution. Complete this one-time setup:

1. In Google Cloud IAM, create a dedicated service account for GitHub Actions.
2. Grant it the **Firebase App Distribution Admin** role for the Firebase
   project, then download a JSON key.
3. Add the complete JSON document as the GitHub Actions repository secret
   `FIREBASE_SERVICE_ACCOUNT_JSON`.
4. In Firebase App Distribution, create a tester group. Add its alias to the
   optional GitHub Actions repository variable `FIREBASE_TESTER_GROUPS`.
   Multiple aliases can be comma-separated. If this variable is omitted, the
   release is uploaded but no group is notified automatically.

The workflow uses Firebase Android app ID
`1:715512178126:android:cf70974901bb38d482779f`. The generated APK is also kept
as a private GitHub Actions artifact for 14 days.

## Cross-platform verification

Pull requests build Linux, Windows, macOS, and unsigned iOS release targets.
Web and Android release builds are validated by their deployment workflows on
`main`. This keeps production deployments focused while still detecting
platform-specific failures before a merge.

The official Firebase Flutter plugins currently support Android, iOS, macOS,
web, and Windows, but not native Linux. The Linux build therefore starts with a
clear compatibility screen instead of crashing. Use the web build on Linux for
the complete connected experience, or add a separate REST/backend adapter if
native Linux Firebase access becomes a requirement.

Firestore's offline cache is enabled for Android, iOS, macOS, and web. It
automatically queues local writes and synchronizes them when connectivity
returns. The official Windows and Linux implementations do not provide the
same persistent Firestore cache, so the application does not promise offline
data synchronization on those two native platforms.

## Rollback

Revert the problematic commit on `main`, or select an older commit and run the
workflow manually after temporarily creating a branch from that commit. A new
successful deployment replaces the generated production files with that build.
