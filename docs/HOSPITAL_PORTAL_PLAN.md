# VitaNet Hospital Portal — Plan

## Purpose
Close the loop between a patient's VitaNet triage and the hospital that will see them:
a patient whose check comes back urgent can send their summary to a hospital, and
that hospital's staff receive it, accept it, treat the patient and close the case —
with the patient kept informed. Everything the portal shows comes from real records;
no sample data in production.

## Who uses it
| Role | Can do |
|---|---|
| **Admin** (facility manager) | Everything below + approve/suspend staff, edit facility profile and capacity |
| **Doctor** | Accept/decline referrals, own cases, write notes, discharge |
| **Nurse** | Triage queue, vitals, notes, bed moves, attend alerts |

Access: staff sign up → **pending** until a facility admin approves (built). Each staff
account belongs to **one hospital**; every query is scoped to that hospital.

## Core flow
1. Patient triage = urgent/doctor → result screen offers **"Send my summary to <nearest hospital>"**
   with explicit consent (what is shared: symptoms, triage level, vitals, allergies, meds, age/sex).
2. A **Referral** appears in that hospital's *Incoming* inbox in real time (ETA from patient location).
3. Staff **Accept** (assign clinician + bed → creates a **Case**) or **Decline** with reason
   (patient is told and shown the next nearest A&E).
4. Case moves **Waiting → In treatment → Discharged**; notes, vitals and status changes go on
   the case timeline. Patient app shows referral status ("Accepted — go to Emergency, ask for Dr Addo").
5. Every action is written to an **audit log** (who, what, when).

## Screens
1. **Access states** — sign in / sign up, *Pending approval*, *Rejected*, *Suspended*.
2. **Today (dashboard)** — live counts (incoming, waiting, in treatment, critical alerts, beds free),
   incoming referrals, my cases, shift banner.
3. **Referrals** — New / Accepted / Declined tabs; referral detail with the consented patient
   summary; Accept (assign + bed) / Decline (reason).
4. **Cases** — board by status with filters (mine, level, ward); **Case record**: patient summary,
   vitals timeline, notes, status, bed, assignee, discharge summary.
5. **Alerts** — real alerts only (urgent vitals from consenting patients, referral/case events);
   attend with action + note.
6. **Hospital** — wards (occupied/total beds, editable), equipment (available/total, editable),
   on-duty team from approved staff accounts.
7. **Team** (admin) — approval requests, roles, suspend/reactivate.
8. **Settings** — profile, notifications, password, **facility profile** (admin: name, address,
   map location, ER/ambulance availability — this feeds the patient app's "nearest A&E").

## Backend changes
- `StaffAccount.hospital_id`; all `/admin/*` queries scoped to it.
- New `Referral` (patient user, hospital, triage snapshot, consent timestamp, status, ETA, decline reason).
- `Case` linked to referral + patient; structured fields (created_at instead of "31 min" strings).
- Capacity as numbers (`beds_total/occupied`, `equipment available/total`).
- `AuditLog`; staff list = approved staff accounts (+ shift status).
- Patient endpoints: create referral (consent), get referral status.
- Seeded demo hospital data only in staging, never in production.

## Delivery phases
1. **Backend** — facility scoping, referrals, cases, capacity, audit, team endpoints + tests.
2. **Portal UI** — all screens above, empty/loading/error states, no demo fallbacks.
3. **Patient app** — "Send to hospital" consent sheet + referral status card on triage result & home.
4. **Test on staging** (VPS staging copy + Firebase preview) → production deploy (needs owner approval).
