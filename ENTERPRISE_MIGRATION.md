# Enterprise clinic migration

The application now isolates operational data below a clinic document:

```text
clinics/{clinicId}/patients/{id}
clinics/{clinicId}/appointments/{id}
clinics/{clinicId}/prescriptions/{id}
clinics/{clinicId}/stocks/{id}
clinics/{clinicId}/invoices/{id}
clinics/{clinicId}/finance_entries/{id}
clinics/{clinicId}/vaccinations/{id}
clinics/{clinicId}/reminders/{id}
clinics/{clinicId}/audit_logs/{id}
clinics/{clinicId}/team_invites/{id}
```

## User profile fields

Every staff profile in `users/{uid}` should contain:

```json
{
  "active_clinic_id": "clinic-id",
  "clinic_ids": ["clinic-id"],
  "clinic_roles": {"clinic-id": "clinic_admin"}
}
```

Legacy users without these fields are assigned to `default-clinic` in the
client. Before deploying the new Firestore rules, create the `default-clinic`
document, add these fields to existing users, and copy legacy top-level data
into the matching `clinics/default-clinic/...` subcollections.

The new rules make legacy top-level operational collections read-only to the
Platform Owner. This is intentional: it prevents newly created records from
remaining outside a clinic boundary.

## Deployment order

1. Back up Firestore.
2. Create clinic documents and update user memberships.
3. Copy legacy operational records to clinic subcollections.
4. Deploy the web/mobile application.
5. Deploy `firestore.rules`.
6. Verify each role against at least two clinics before removing legacy data.

Do not delete the top-level legacy collections until record counts and totals
have been reconciled and a rollback backup has been tested.
