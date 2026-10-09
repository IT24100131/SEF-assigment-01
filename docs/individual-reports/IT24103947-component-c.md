# Component C integration — IT24103947

Assigned member: Walimuniarachchi W.A.K.S (IT24103947).
Component: Bidding Engine & Buyer Matching, as assigned in the project report.
This integrates supplied team project code and records the assigned component;
it does not establish original authorship of the team's existing implementation.

## Changes

- Bid validation rejects nonpositive prices and existing noncancelled buyer bids.
- Accept/reject actions enforce Fisherman/Admin roles and catch ownership in all environments.
- Bid acceptance creates an order, marks the catch sold, and supplies the existing logistics request fields.
- Buyer preference list, validation, individual edit/delete and recommendations support multiple saved preferences.
- React buyer dashboard contains preference, matching and bidding flows; the shared fisherman dashboard gains bid actions/history.
- React navigation exposes saved preferences and preference editing. The preexisting import/render of the missing Footer component is removed.
- Shared API error formatter supports the updated buyer UI.
- Python scorer handles empty and substring species preferences; other agents and the ApiRequest model remain unchanged.
- Flutter buyer dashboard/preferences, browse/detail, bid form and bid history are integrated into existing main.dart with preference API methods.

Shared catch registration UI, authentication screens, logistics dashboard and the team README are retained.
Bid.cs is unchanged and needs no new commit. Full source files remain in their existing project paths.
This PR does not add the component-only reference excerpts to the running app.

## Validation

- Updated React files pass TypeScript checks; production frontend build passes.
- Six Python helper tests pass, including two new species preference cases.
- Patch application is checked against main commit 8904f8b7e6ba3cbea7b9db54bf902eeb8af3fb67.
- Backend and Flutter builds still require checks on a machine with their SDKs.
- The current main branch targets net11.0 in both API and API test project files; verify these against the working team's SDK/project configuration before merging.

Bid increment/concurrency rules claimed in the report are not added by this integration.
The duplicate bid check is application-level and does not guarantee race-free concurrent placement.
Existing demo/fallback data in the mobile UI is preserved.
