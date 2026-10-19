# Google/Firebase AI preparation

Existing project: `clinical-solution-5dc1d`. No paid API activation, billing change or clinical-data transmission was performed. Code is prepared; AI stays disabled by default.

## Prepared behavior

- Callable `prepareClinicalAiDraft` in `asia-south1`, requiring Firebase Auth and App Check.
- Approved doctor/clinic-admin membership, active clinic, enabled clinical/laboratory module and explicit clinic `ai_enabled: true`. Platform owners still require approval, clinic activation and opt-in.
- Tasks: `lab_text`, `translation` (en/hi/gu), `consultation_summary`; maximum 20,000 source characters. No diagnosis, dose generation, binary upload or automatic chart write.
- Server application-default credentials call Vertex AI in the same project. No client provider key.
- Hard caps: 100 attempts/clinic and 20/user per UTC day. Failed attempts count to limit retry spend. This is a safeguard, not a subscription-credit ledger.
- Lab values require verbatim numeric source evidence; altered numeric tokens in translations are rejected. Validation cannot establish clinical correctness or drug-name fidelity: clinicians must review original and draft.
- Usage metadata/application logs exclude raw prompts/results and patient identifiers. Google processes submitted text; establish consent, retention and regional requirements before release.
- Flutter adapter defaults to disabled, requires ID/App Check token callbacks and reviewable responses. It is not wired to patient forms before the review UI exists.

## Activation gates

1. Confirm Vertex API availability, organization policy, billing alerts and region in the existing project. Billable activation is a separate owner action.
2. Select a currently supported Gemini model and verify its price, limits and data handling. `CLINIC_AI_MODEL` has **no default**. `CLINIC_AI_LOCATION` defaults to `asia-south1`; use `global` only after an explicit data-residency decision.
3. Use a dedicated runtime identity with the required Vertex prediction role, not Owner/Editor. Configure client App Check; do not disable server enforcement as a workaround.
4. Deploy coordinated function/rules configuration with `CLINIC_AI_ENABLED` absent or `false`. Only after validation set it to `true`, supply a model, and opt in individual clinics.
5. Implement source/draft review side by side, explicit patient selection, editable values/units/ranges, source date review and explicit clinician save. Retain original translations and verify medicine names/doses/units. Note organization is not diagnostic assistance.
6. Add secure PDF/image ingestion with MIME/content/size checks and retention before describing lab extraction as “scan.” Current support accepts text only, not file URLs or storage paths.
7. Test synthetic reports in a non-production project: malformed/provider-rejected output, App Check/role changes, concurrent quotas and no automatic save. Measure spend before production opt-in.

Client flags are not authorization. The server independently checks all gates; opening a screen must never trigger a provider call.

References: [callable protocol](https://firebase.google.com/docs/functions/callable-reference), [App Check](https://firebase.google.com/docs/app-check/cloud-functions), [Vertex authentication and quickstart](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/start/quickstart).
