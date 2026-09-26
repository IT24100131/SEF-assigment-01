# FishLink AI

FishLink is an integrated fish-marketplace application for fishermen, buyers,
administrators and logistics staff. React and Flutter are client applications;
both use the same ASP.NET Core API, PostgreSQL database, identity model and
business rules. The Python agent is an internal service called by the API only.

## Repository

| Project | Purpose | Local command |
| --- | --- | --- |
| `FishLink.API` | ASP.NET Core REST API, EF Core and PostgreSQL integration | `dotnet run --project FishLink.API` |
| `FishLink.API.Tests` | xUnit service and controller tests | `dotnet test FishLink.API.Tests` |
| `fishlink-dashboard` | React web client | `npm ci && npm start` |
| `fishlink_mobile` | Flutter mobile client | `flutter pub get && flutter run` |
| `ai_agent` | Internal Agentic AI HTTP service | `uvicorn main:app --reload --port 8000` |
| `price_api` | Internal fish-price prediction service | `uvicorn main:app --reload --port 8001` |

## Setup

1. Install .NET 11 SDK, PostgreSQL, Node.js 20+, Flutter and Python 3.12+.
2. Create a PostgreSQL database and set `ConnectionStrings:DefaultConnection`
   in user secrets or an environment-specific settings file.
3. Set `Jwt:Key`, `Jwt:Issuer` and `Jwt:Audience` through user secrets or
   environment variables. Never commit credentials.
4. From the API directory run `dotnet ef database update`, then
   `dotnet run -- --seed` to add demonstration data.
5. Start the internal price service from `price_api` with
   `uvicorn main:app --reload --port 8001`. The API proxies market forecasts
   through this service; keep it running while using Market Intelligence.
6. Run the API and confirm `GET /health` and `/swagger` before starting either
   client.
7. Start the React client from `fishlink-dashboard`.
8. Start Flutter with
   `flutter run --dart-define=FISHLINK_API_URL=http://10.0.2.2:5000/api`
   for the Android emulator. Use the deployed HTTPS API URL for a device.

The mobile app stores the JWT in platform secure storage, uses API validation
for login and catch creation, and calls the API for weather safety. Camera and
GPS are device features; their permissions are declared in Android and iOS.

## Testing and CI

Run `dotnet test FishLink.API.Tests` for backend unit tests and
`flutter test` in `fishlink_mobile` for mobile widget tests. The GitHub Actions
workflow builds the API, runs xUnit tests, builds the React application and
runs Flutter analysis/tests.

## Architecture and evidence

The rationale for the technology and integration choices is recorded in
[`docs/adr/0001-integrated-architecture.md`](docs/adr/0001-integrated-architecture.md).
The API is the only public integration boundary: clients never call the Python
agent directly. Demonstration users and workflow data are created by
`DataSeeder`; replace all seeded passwords before a real deployment.
