# Deployment and evidence checklist

This is an execution checklist, not fabricated deployment evidence. Fill the
URLs only after a real deployment and HTTP verification.

The repository includes [`render.yaml`](../render.yaml) and Dockerfiles for a
Render deployment. Connect PostgreSQL through Neon or Supabase and set every
`sync: false` value in the Render dashboard. Render service URLs are generated
only after the services are actually created.

## API and database

- [ ] Provision PostgreSQL and store the connection string as a secret.
- [ ] Configure `Jwt:Key`, `Jwt:Issuer`, `Jwt:Audience`, AI and weather settings
      through environment variables or deployment secrets.
- [ ] Run EF migrations and seed only demonstration data.
- [ ] Verify `/health`, `/swagger` and role-protected endpoints.
- [ ] Verify logs do not contain passwords, JWT keys or connection strings.

## Agent services

- [ ] Deploy the internal Agentic AI and price services on private networking.
- [ ] Configure API `AiAgent:BaseUrl` and `PriceApi:BaseUrl`.
- [ ] Verify `/api/AgentGateway/agent/health` through the API.
- [ ] Run one low-risk workflow and one high-risk workflow.
- [ ] Capture persisted state, tool summary, admin approval and safe failure.

## React, Flutter and artifacts

- [ ] Set React API base URL to the deployed API.
- [ ] Build and deploy React.
- [ ] Build the APK with the deployed API URL:
      `flutter build apk --release --dart-define=FISHLINK_API_URL=<API>/api`
- [ ] Install the APK on a clean Android device/emulator.
- [ ] Test camera, GPS, login, catch submission, loading and error states.
- [ ] Upload the APK to the private submission/evaluator location.

## Final URLs and artifact

- React: `[TO COMPLETE]`
- API: `[TO COMPLETE]`
- Swagger: `[TO COMPLETE]`
- Health: `[TO COMPLETE]`
- Agent health: `[TO COMPLETE]`
- APK: `[TO COMPLETE]`
- Successful GitHub Actions run: `[TO COMPLETE]`

## Render deployment order

1. Create the Render Blueprint from `render.yaml`.
2. Create a Neon/Supabase PostgreSQL database and copy its pooled connection
   string to `ConnectionStrings__DefaultConnection`.
3. Set the JWT secret and service base URLs in the Render dashboard.
4. Update the API URL used by the React client and Flutter APK build.
5. Run migrations, seed demonstration data, and verify every URL above.
