# FishLink AI - SE3090 Assignment 1 Consolidated Report

> **Submission document:** replace every `[TO COMPLETE]` item with evidence
> produced by the group. Do not claim a URL, screenshot, test result or
> contribution that was not actually verified.

## 1. Group report

### 1.1 System summary

FishLink is an integrated fish-marketplace system for fishermen, buyers,
administrators and logistics staff. React and Flutter use the same ASP.NET
Core API, PostgreSQL data model, JWT identity and role-based business rules.
The private Python Agentic AI service is called by ASP.NET Core only.

### 1.2 Group members and ownership

| Student | Registration number | Primary component | Evidence links |
| --- | --- | --- | --- |
| [TO COMPLETE] | [TO COMPLETE] | [TO COMPLETE] | [TO COMPLETE] |
| [TO COMPLETE] | [TO COMPLETE] | [TO COMPLETE] | [TO COMPLETE] |
| [TO COMPLETE] | [TO COMPLETE] | [TO COMPLETE] | [TO COMPLETE] |
| [TO COMPLETE] | [TO COMPLETE] | [TO COMPLETE] | [TO COMPLETE] |

### 1.3 Architecture

The accepted architecture decision is in
[`docs/adr/0001-integrated-architecture.md`](./adr/0001-integrated-architecture.md).
Add the final ER diagram and system/component diagram here:

- ER diagram: `[TO COMPLETE: relative image or repository link]`
- Deployment diagram: `[TO COMPLETE: relative image or repository link]`
- Agent workflow/state diagram: `[TO COMPLETE: relative image or repository link]`

### 1.4 Deployment and evaluator access

| Resource | URL / artifact | Verification date |
| --- | --- | --- |
| React application | `[TO COMPLETE]` | `[TO COMPLETE]` |
| ASP.NET Core API | `[TO COMPLETE]` | `[TO COMPLETE]` |
| Swagger | `[TO COMPLETE]` | `[TO COMPLETE]` |
| Health endpoint | `[TO COMPLETE]` | `[TO COMPLETE]` |
| Flutter APK | `[TO COMPLETE: release APK link]` | `[TO COMPLETE]` |
| Agent health through API | `[TO COMPLETE]` | `[TO COMPLETE]` |

Credentials must be provided through the LMS/private evaluator channel, not
committed to Git. Record the evaluator roles and where the credentials are
stored: `[TO COMPLETE]`.

### 1.5 Demonstration evidence

Add numbered screenshots or short screen recordings to `docs/evidence/` and
link them below:

1. Role-based login and protected operation: `[TO COMPLETE]`
2. Catch CRUD and PostgreSQL change: `[TO COMPLETE]`
3. Swagger endpoint: `[TO COMPLETE]`
4. React and Flutter using the same catch: `[TO COMPLETE]`
5. AI plan, agents, tools and persisted state: `[TO COMPLETE]`
6. Admin approval/rejection and execution history: `[TO COMPLETE]`
7. Error handling and test output: `[TO COMPLETE]`
8. Deployment and APK installation: `[TO COMPLETE]`

### 1.6 Testing and CI evidence

| Layer | Command / workflow | Result | Evidence |
| --- | --- | --- | --- |
| Backend unit | `dotnet test FishLink.API.Tests/FishLink.API.Tests.csproj` | 5 tests passed locally | `[TO COMPLETE: CI URL]` |
| Flutter | `flutter analyze; flutter test` | Passed locally | `[TO COMPLETE]` |
| React | `npm run build` | Compiled successfully locally | `[TO COMPLETE]` |
| Integration | `[TO COMPLETE: API + PostgreSQL test command]` | `[TO COMPLETE]` | `[TO COMPLETE]` |
| Performance | `[TO COMPLETE: measured command/tool]` | `[TO COMPLETE]` | `[TO COMPLETE]` |
| Agentic AI evaluation | `python -m unittest discover -s ai_agent/tests` | `[TO COMPLETE after run]` | `[TO COMPLETE]` |

GitHub Actions run: `[TO COMPLETE: actual successful run URL]`.

## 2. Agentic AI evaluation

The workflow has Planning, Quality Validation, Market Intelligence, Buyer
Matching and Logistics Scheduling responsibilities. The workflow persists
status through the API, uses allow-listed tools, performs deterministic
validation, pauses for admin approval when risk is high, and emits an
auditable status summary.

Complete this table using a real demonstration run:

| Acceptance requirement | Evidence |
| --- | --- |
| Domain objective and structured input | `[TO COMPLETE]` |
| Distinct agent roles | `[TO COMPLETE]` |
| Allow-listed tool calls | `[TO COMPLETE]` |
| Persisted workflow state | `[TO COMPLETE]` |
| Deterministic validation thresholds | `[TO COMPLETE]` |
| Human/admin approval | `[TO COMPLETE]` |
| Safe failure when an internal service is offline | `[TO COMPLETE]` |
| Execution-history summary | `[TO COMPLETE]` |

## 3. Group AI-use declaration

We confirm that AI tools were used only during permitted development tasks,
that all generated work was reviewed and tested, that no confidential data or
secrets were supplied, and that every member can explain, modify and debug the
work attributed to them.

Group members: `[TO COMPLETE]`  
Date: `[TO COMPLETE]`  
Signatures/approval: `[TO COMPLETE]`

## 4. Individual reports

The individual sections are maintained in
[`docs/individual-reports/`](./individual-reports/). Each member must complete
their own section, including ownership, commits/PRs, technical explanation,
tests, AI log and reflection. Never copy another member's reflection.
