# FishLink — Smart Seafood Logistics & Autonomous Trading Platform
## Student 1 Individual Submission & Git Repository Package

* **Assigned Student**: Student 1
* **Assigned Role**: Component A - Fish Catch Registration, Harbor Pier Inspection & Discrepancy Auditing
* **Assigned Agentic AI**: Quality Validation & Fraud Detection Agent
* **Git Feature Branch**: `feature/student-1-catch-quality`
* **Individual Contribution Report**: See [`STUDENT_CONTRIBUTION_REPORT.md`](./STUDENT_CONTRIBUTION_REPORT.md)

---

### 📌 Student 1 Key Components & Files Owned:
  * `FishLink.API/Controllers/CatchesController.cs`
  * `FishLink.API/Controllers/QualityController.cs`
  * `FishLink.API/Models/Catch.cs`
  * `FishLink.API/Models/QualityCheck.cs`
  * `fishlink-dashboard/src/components/Dashboards/FishermanDashboard.tsx`
  * `fishlink-dashboard/src/components/Dashboards/QualityDashboard.tsx`
  * `fishlink-dashboard/src/components/CatchRegistrationModal.tsx`
  * `fishlink_mobile/lib/main.dart (NewCatchScreen, CatchRegistration)`
  * `fishlink_mobile/lib/features_15_25.dart (_QualityModalContent, Catch C103/C104 Verification)`
  * `ai_agent/main.py (Quality Validation & Fraud Detection Agent)`

---

### 🚀 How to Push this Project to Your GitHub Repository

You can push this complete working project under your own GitHub account and branch using the provided helper script:

#### Option 1: Automated Script (One Click / Command)
Open Command Prompt in this folder and run:
```cmd
git_push_setup.bat https://github.com/YOUR_USERNAME/FishLink-Student1.git
```
*(Replace `https://github.com/YOUR_USERNAME/...` with your actual empty GitHub repository URL)*

#### Option 2: Step-by-Step Manual Git Commands
Run the following commands in Terminal / PowerShell:

```bash
# 1. Initialize Git repository
git init

# 2. Set your GitHub Identity
git config user.name "Student 1"
git config user.email "student1@my.sliit.lk"

# 3. Create and switch to your feature branch
git checkout -b feature/student-1-catch-quality

# 4. Stage and commit initial base project
git add .
git commit -m "feat(component-a): implement catch ingestion, pier inspection, quality verification and fraud detection agent"

# 5. Link to your GitHub remote repository
git remote add origin https://github.com/YOUR_USERNAME/FishLink-Student1.git

# 6. Push your branch
git push -u origin feature/student-1-catch-quality
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
