# Product Owner access and account approval

## Recovery after deleting Firestore profiles
Deleting Firestore does not delete Firebase Authentication users. Do not re-register an existing sign-in account or make the first new registrant an owner.

A trusted Firebase project administrator must locate the intended account in Authentication, copy its UID, and recreate or update `users/{UID}` with `role: platform_owner`, `status: approved`, its existing Auth email and `email_normalized`. A new profile also needs `name`, `phone`, empty `clinic_ids`, `clinic_roles` and `clinic_role_lists`, empty `active_clinic_id`, and timestamp fields `createdAt`/`updated_at`. Preserve clinic memberships if the profile already exists. Use privileged Firebase administration; normal users must never be able to promote themselves through public registration.

Sign out and sign back in after restoring the profile. Product Owner opens the All clinics platform workspace.

## Approve new clinic users
Open **Team & roles**. Pending requests display **Access: awaiting owner approval**. Select the check icon (**Approve request**), choose an existing clinic or create the requested clinic, select the approved role, and confirm **Approve & activate**. This sets approved access and clinic membership. The cancel icon rejects/removes the registration; use it only when rejecting the request intentionally.

## Email verification
Owner approval and email verification are different. Firebase Authentication owns `emailVerified`; it is completed by the recipient redeeming the valid email link. Do not treat a clinic notification failure or an owner approval as proof that an email is verified. Check the Auth user in Firebase Console when diagnosing verification issues.

Clinic notification failures do not revoke an existing verified email or an approved account. MSG91 is disabled until provider setup is completed; see MESSAGING_CONFIGURATION.md and email-templates/README.md.
