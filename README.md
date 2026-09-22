# FishLink — Smart Seafood Logistics & Autonomous Trading Platform
## Student 2 Individual Submission & Git Repository Package

* **Assigned Student**: Student 2
* **Assigned Role**: Component B - Dynamic Market Intelligence, Pricing & Marine Safety
* **Assigned Agentic AI**: Market Intelligence & Price Trend Agent
* **Git Feature Branch**: `feature/student-2-market-pricing`
* **Individual Contribution Report**: See [`STUDENT_CONTRIBUTION_REPORT.md`](./STUDENT_CONTRIBUTION_REPORT.md)

---

### 📌 Student 2 Key Components & Files Owned:
  * `FishLink.API/Controllers/AgentGatewayController.cs`
  * `FishLink.API/Controllers/WeatherController.cs`
  * `FishLink.API/Services/WeatherService.cs`
  * `price_api/main.py`
  * `fishlink-dashboard/src/components/Dashboards/MarketDashboard.tsx`
  * `fishlink-dashboard/src/components/PriceChart.tsx`
  * `fishlink-dashboard/src/components/WeatherSafetyAdvisory.tsx`
  * `fishlink_mobile/lib/main.dart (MarketScreen, showAiPriceRecommendationModal - Tuna Rs.1550-1650/kg, 87% Confidence)`
  * `ai_agent/main.py (Market Intelligence & Price Trend Agent)`

---

### 🚀 How to Push this Project to Your GitHub Repository

You can push this complete working project under your own GitHub account and branch using the provided helper script:

#### Option 1: Automated Script (One Click / Command)
Open Command Prompt in this folder and run:
```cmd
git_push_setup.bat https://github.com/YOUR_USERNAME/FishLink-Student2.git
```
*(Replace `https://github.com/YOUR_USERNAME/...` with your actual empty GitHub repository URL)*

#### Option 2: Step-by-Step Manual Git Commands
Run the following commands in Terminal / PowerShell:

```bash
# 1. Initialize Git repository
git init

# 2. Set your GitHub Identity
git config user.name "Student 2"
git config user.email "student2@my.sliit.lk"

# 3. Create and switch to your feature branch
git checkout -b feature/student-2-market-pricing

# 4. Stage and commit initial base project
git add .
git commit -m "feat(component-b): implement dynamic market pricing, weather safety advisory, and market intelligence agent"

# 5. Link to your GitHub remote repository
git remote add origin https://github.com/YOUR_USERNAME/FishLink-Student2.git

# 6. Push your branch
git push -u origin feature/student-2-market-pricing
```

---

### 💻 How to Run the Systems Locally

#### 1. ASP.NET Core Web API (Backend)
```bash
cd FishLink.API
dotnet run
# Server runs on: http://localhost:5157 (Swagger: http://localhost:5157/swagger)
```

#### 2. React Web Dashboard (Web Client)
```bash
cd fishlink-dashboard
npm install
npm run dev
# Dashboard runs on: http://localhost:5173
```

#### 3. Flutter Mobile Application (Cross-Platform Mobile/Web)
```bash
cd fishlink_mobile
flutter pub get
flutter run -d chrome --web-port=8080
# Mobile App runs on: http://localhost:8080
```

#### 4. Python Agentic AI Service
```bash
cd ai_agent
pip install -r requirements.txt
python main.py
```
