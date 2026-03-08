---
# How to Run DCRRA
### Defence Convoy Route Risk Analyzer

---

## What You Need First
* Python 3.10+ (https://www.python.org/downloads/)
* Flutter 3.x (https://docs.flutter.dev/get-started/install)
* Git (https://git-scm.com/downloads)

---

## Step 1 — Set Up Your API Keys
The `.env` file holds your private API names and passwords to allow the application to securely fetch data.
In the `backend` folder, duplicate `.env.example`, rename it to `.env`, and fill in the values:

```
# backend/.env
SUPABASE_URL=your_supabase_project_url (Get from: https://supabase.com/dashboard)
SUPABASE_KEY=your_supabase_anon_key (Get from: https://supabase.com/dashboard)
ENVIRONMENT=development
```

---

## Step 2 — Start the Backend (Python)

**On Mac/Linux:**
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*(Or simply double-click / run `./run_backend.sh` from the root folder)*

**On Windows:**
```cmd
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
*(Or simply double-click `run_backend.bat` from the root folder)*

**What you should see when it works:**
```
INFO:     Started server process [1234]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

---

## Step 3 — Start the App (Flutter)

**On Mac/Linux:**
```bash
cd frontend
flutter pub get
flutter run
```
*(Or simply double-click / run `./run_flutter.sh` from the root folder)*

**On Windows:**
```cmd
cd frontend
flutter pub get
flutter run
```

**What you should see when it works:**
```
Running "flutter pub get" in frontend...                           1.2s
Launching lib/main.dart on macOS in debug mode...
Building macOS application...                                      10.5s
Syncing files to device macOS...                                    2.1s
Flutter run key commands.
h List all available interactive commands.
c Clear the screen
q Quit (terminate the application on the device).
```

---

## Step 4 — Use the App

1. The app opens — you will see a dark interactive map centered on the selected operational zone.
2. Use the **search bar** at the top right to find a specific deployment location or threat center.
3. Click directly on the map to set a **Convoy Origin** (starting point).
4. Click on the map again to set a **Convoy Destination** (ending point).
5. Open the **Intel Feed** panel to toggle live risk overlays, aircraft positions, and ground traffic data.
6. Press **Compute Route** to activate the solver algorithm to find safe paths.
7. A menu will pop up showing the **k-shortest paths** found, categorized by risk probability and distance.
8. Click on any proposed route card to visualize it on the map in full scale. You can also export the report as a PDF.

---

## Something Went Wrong?

| Problem | Fix |
|---------|-----|
| Backend won't start | Ensure you activated the virtual environment (`source venv/bin/activate`) before running `uvicorn`. Make sure no other apps are using port 8000. |
| Map is blank | Check your internal internet connection. The map requires open access to fetch OpenStreetMap tiles. |
| Search not working | Ensure the backend is actively running, as location geocoding passes through your Python endpoint pipeline. |
| Aircraft not showing | Wait a few seconds for the live data feed to propagate, or zoom outwards. |
| Route not computing | Look at the backend terminal window. Make sure you set the origin and destination to reachable road networks and not oceans or unmapped empty spaces. |

---

## Stopping the App

To stop the Python Backend, click the terminal window running it and press `CTRL + C`.
To stop the Flutter App, click the terminal window running it and press `q`.
