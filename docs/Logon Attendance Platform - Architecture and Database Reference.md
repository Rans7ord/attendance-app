# Logon Attendance Platform — Architecture & Database Reference

Project: Logon Attendance Platform
Prepared by: Ransford, Logonvoice Limited
Version: 1.0 — 21 July 2026

This is a working technical reference, not a formal spec — meant to be pulled up once development starts.

---

## 1. System Architecture

```
                 ┌────────────────────┐   ┌──────────────────────┐
                 │  Flutter mobile app │   │  Flutter mobile app   │
                 │  (member clock-in)  │   │  (shared/kiosk device)│
                 └──────────┬──────────┘   └───────────┬───────────┘
                             \                          /
                              \                        /
                     ┌─────────▼──────────────────────▼─────────┐
                     │        Laravel REST API (single API)      │
                     │  Auth · Attendance · Shifts · Leave ·      │
                     │  Reports · Notifications · Admin           │
                     └───────────────┬─────────────────┬─────────┘
                                     │                 │
                        ┌────────────▼─────┐   ┌───────▼────────────┐
                        │   MySQL database  │   │  Firebase Cloud     │
                        │                    │   │  Messaging (push)   │
                        └────────────────────┘   └─────────────────────┘

                 ┌────────────────────────┐
                 │  Web admin dashboard    │  ← also calls the same Laravel API
                 │  (HR / Finance / Mgmt)  │
                 └────────────────────────┘
```

**Principle:** one Laravel API, one MySQL database, consumed by three front-ends — the member-facing Flutter app, a shared/kiosk instance of that same app, and a web admin dashboard. Nobody gets a separate backend or a separate copy of business logic. Admin/manager roles can also log into the mobile app for lightweight tasks (leave approvals, a quick attendance glance); deep reporting and bulk admin work live on the web dashboard.

**Multi-tenant + RBAC from day one:** every business-scoped table carries `company_id` (enforced via Laravel global scopes, not just convention), and access is governed by a proper `roles`/`permissions` model rather than a single role string — see Section 2 for the tables.

### Layers

| Layer | Technology | Responsibility |
|---|---|---|
| Mobile client | Flutter (Dart) | Clock in/out, GPS + biometric capture, offline queuing, member/manager views |
| Web client | Laravel Blade or a JS framework consuming the same API | HR/Finance/Management reporting, bulk admin |
| API | Laravel (PHP) | Auth, business rules, validation, report generation |
| Database | MySQL | System of record |
| Push notifications | Firebase Cloud Messaging | Late-arrival alerts, missed clock-out reminders, leave notifications |

### Mobile app folder structure

```
lib/
├── core/
│   ├── constants/
│   ├── services/        ← API client (dio), geolocator wrapper, local_auth wrapper
│   ├── theme/
│   └── utils/
├── features/
│   ├── auth/
│   ├── attendance/       ← clock in/out, GPS, biometric
│   ├── employees/        ← member registration, profile photo
│   ├── shifts/
│   ├── leave/
│   ├── reports/          ← HR / Finance / Management views
│   ├── profile/
│   └── settings/
├── shared/
│   ├── widgets/
│   ├── models/
│   └── providers/
└── main.dart
```

### Core API endpoints (grouped by module)

```
Auth
  POST   /login
  POST   /logout
  POST   /register-device

Attendance
  POST   /clock-in
  POST   /clock-out
  GET    /attendance                 (history, filterable)
  GET    /attendance/{member_id}

Members
  GET    /members
  POST   /members
  PUT    /members/{id}
  POST   /members/{id}/photo

Shifts
  GET    /shifts
  POST   /shifts
  POST   /shifts/{id}/assign

Leave
  GET    /leave-requests
  POST   /leave-requests
  PUT    /leave-requests/{id}/approve
  PUT    /leave-requests/{id}/reject

Reports
  GET    /reports/hr/daily
  GET    /reports/hr/monthly
  GET    /reports/hr/lateness
  GET    /reports/finance/hours
  GET    /reports/finance/payroll-export
  GET    /reports/management/trends

Admin
  GET    /audit-logs
  GET    /roles
  POST   /companies/{id}/policies
```

---

## 2. Database Schema

Naming convention: snake_case table and column names, singular concept / plural table name, every table has `id` (PK), `created_at`, `updated_at` (omitted below for brevity — assume every table has them).

**Multi-tenant rule:** this platform is multi-tenant from day one. Every business-scoped table below carries `company_id`, and every model for those tables gets a Laravel **global scope** that auto-filters by the logged-in user's company — so a missing `WHERE company_id = ?` in a hand-written query can't leak one company's data to another. Don't rely on remembering to filter manually.

**Auth rule:** authentication lives in Laravel's standard `users` table, not on `members`. A `members` row is "someone tracked for attendance"; a `users` row is "someone who logs in." Company Admins, HR, Finance, and Supervisors need a `users` row. Smartphone-owning members log in via `users` too. Members who only ever clock in at a shared/kiosk device can be identified by a PIN against their `members.id` without necessarily needing a full `users` account — keeps registration friction low for exactly the group the shared device exists to serve.

### companies
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| name | varchar | |
| industry | varchar | e.g. Corporate, Education, Church, Security, Construction |
| logo_path | varchar, nullable | |
| address | varchar | |

### users
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| email | varchar | |
| password | varchar, hashed | |
| status | varchar | active / suspended |

### roles
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| name | varchar | Company Admin / HR / Finance / Supervisor / Employee / Student ... |

### permissions
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| name | varchar | e.g. create_member, delete_member, view_payroll, approve_leave, export_reports |

### role_permissions
| Column | Type | Notes |
|---|---|---|
| role_id | bigint, FK → roles.id | |
| permission_id | bigint, FK → permissions.id | many-to-many |

### user_roles
| Column | Type | Notes |
|---|---|---|
| user_id | bigint, FK → users.id | |
| role_id | bigint, FK → roles.id | many-to-many, usually one role per user in practice |

### branches
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| name | varchar | |
| address | varchar | |
| gps_lat | decimal | branch center point, for geofence radius check |
| gps_lng | decimal | |
| geofence_radius_m | int | meters allowed from branch center for a valid clock-in |

### departments
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| branch_id | bigint, FK → branches.id | |
| name | varchar | e.g. HR, Accounts, Security, Sales |

### members
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| branch_id | bigint, FK → branches.id | |
| department_id | bigint, FK → departments.id | |
| user_id | bigint, FK → users.id, nullable | null for shared-device-only members with no full login |
| member_number | varchar | |
| first_name | varchar | |
| last_name | varchar | |
| phone | varchar | |
| email | varchar, nullable | |
| photo_path | varchar | captured at registration; used for shared-device identity check |
| position | varchar | job title / label independent of role_id |
| pin | varchar, hashed, nullable | for shared-device identity check when there's no full user login |
| date_joined | date | |
| status | varchar | active / inactive |

### devices
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| member_id | bigint, FK → members.id, nullable | null for a shared device not tied to one member |
| device_uid | varchar | unique device identifier |
| device_name | varchar, nullable | |
| platform | varchar | android / ios |
| shared_device | boolean | true for kiosk/shared entrance devices |
| approved | boolean | for future device-binding change-approval workflow |

### shifts
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| branch_id | bigint, FK → branches.id | |
| type | varchar | morning / afternoon / night / flexible |
| start_time | time | |
| end_time | time | |

### shift_assignments
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| member_id | bigint, FK → members.id | |
| shift_id | bigint, FK → shifts.id | |
| effective_date | date | |

### attendance
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| member_id | bigint, FK → members.id | |
| shift_id | bigint, FK → shifts.id, nullable | |
| device_id | bigint, FK → devices.id | which device recorded this event |
| clock_in | datetime | |
| clock_out | datetime, nullable | |
| gps_lat_in | decimal | captured only at clock-in |
| gps_lng_in | decimal | |
| gps_lat_out | decimal, nullable | captured only at clock-out |
| gps_lng_out | decimal, nullable | |
| mock_location_flag | boolean | set true if spoofed GPS suspected |
| clock_in_method | varchar | biometric / pin / photo |
| clock_out_method | varchar, nullable | biometric / pin / photo |
| working_hours | decimal | computed |
| status | varchar | present / absent / late / on_leave / sick / holiday |
| remarks | varchar, nullable | manager note on an irregular record |

No separate reports table — every HR/Finance/Management report is a query over `attendance` (joined with `members`, `departments`, `leave_requests` as needed), not separately stored data.

### leave_types
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| name | varchar | Annual / Sick / Maternity / Unpaid / Compassionate / Study |

### leave_requests
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| member_id | bigint, FK → members.id | |
| leave_type_id | bigint, FK → leave_types.id | |
| start_date | date | |
| end_date | date | |
| status | varchar | pending / approved / rejected |
| approved_by | bigint, FK → users.id, nullable | |

### notifications
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| member_id | bigint, FK → members.id | |
| type | varchar | late / leave_approved / clockout_reminder / system_notice |
| message | varchar | |
| read_at | datetime, nullable | |

### attendance_policies
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| lateness_threshold_minutes | int | |
| geofence_radius_default_m | int | fallback if a branch doesn't set its own |
| deduction_per_late_incident | decimal, nullable | |
| deduction_per_absence_day | decimal, nullable | |
| overtime_rate_multiplier | decimal, nullable | |

### audit_logs
| Column | Type | Notes |
|---|---|---|
| id | bigint, PK | |
| company_id | bigint, FK → companies.id | |
| actor_id | bigint, FK → users.id | who performed the action |
| action | varchar | |
| target_table | varchar | |
| target_id | bigint | |
| old_value | json, nullable | |
| new_value | json, nullable | |

### Reserved for Version 2 — do not build yet
```
face_verifications
ai_insights
payroll_runs
performance_reviews
visitor_management
```

---

## 3. Backend folder layout (Laravel)

```
app/
├── Models/
├── Http/
│   ├── Controllers/
│   │   ├── Auth/
│   │   ├── Attendance/
│   │   ├── Members/
│   │   ├── Reports/
│   │   ├── Leave/
│   │   └── Settings/
│   └── Requests/
├── Services/
├── Policies/
├── Jobs/
└── Notifications/
```

---

## 4. Design decisions carried into this schema

- **Auth (`users`) is separate from attendance identity (`members`)** — not every login is tracked for attendance (a pure Company Admin), and not every tracked member needs a full login (a shared-device-only worker can use a PIN against their `members` row instead).
- **Multi-tenant by `company_id` on every business table, enforced via Laravel global scopes** — not just present in the schema, but structurally impossible to forget in a query. This is the change that lets Logonvoice host multiple client organizations on one codebase without a future migration.
- **Full RBAC (`roles`, `permissions`, `role_permissions`, `user_roles`)** rather than a single role string — supports the real spread of roles (Company Admin, HR, Finance, Supervisor, Employee, Student, ...) with fine-grained permissions like `approve_leave` or `export_reports`, without hardcoding logic per role name.
- **GPS is captured twice per attendance row** (`gps_lat_in`/`gps_lat_out`), not on a schedule — enforces "snapshot, not tracking" at the data-model level, not just in app logic.
- **`mock_location_flag`** supports the V1 decision to detect spoofed GPS without needing a separate table.
- **`clock_in_method`/`clock_out_method`** record how identity was confirmed (biometric/PIN/photo) — relevant since shared-device clock-ins need a stronger identity check than GPS alone, given the device doesn't move with the member.
- **`branches` carries its own geofence center + radius**, with `attendance_policies.geofence_radius_default_m` as a per-company fallback — so geofencing is configurable per site, not hardcoded.
- **No `reports` table** — every HR/Finance/Management report is a query over `attendance` and its joins, not separately maintained data.
- **Out of scope for V1, deliberately not modeled yet:** `face_verifications`, `ai_insights`, `payroll_runs`, `performance_reviews`, `visitor_management`. Add these only when Version 2 work actually starts.
