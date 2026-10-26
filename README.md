# 🏛️ MEDAL — Municipal Evidence & Development Alignment Ledger

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.141+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Ultralytics YOLO](https://img.shields.io/badge/Ultralytics_YOLO-v8%2Fv11-00FFFF?logo=python&logoColor=black)](https://docs.ultralytics.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Cloud_Storage-3448C5?logo=cloudinary&logoColor=white)](https://cloudinary.com)

**MEDAL** is an intelligent civic engagement and grievance reporting ecosystem connecting citizens with municipal authorities. Citizens capture photo evidence of community issues (waste dumping, potholes, streetlight outages, water leaks), which is instantly analyzed by an on-premise **Ultralytics YOLO** computer vision pipeline, classified into civic issue categories, and mapped to the United Nations **Sustainable Development Goals (SDGs)** before formal submission.

---

## 📌 Architecture Overview

```text
📱 Citizen Mobile (Flutter)
   │
   ├── Capture / Select Photo Evidence
   ├── Immediate Local Preview
   └── Concurrently Trigger Analysis
           │
           ▼
⚡ FastAPI Backend REST API (Port 8000)
   │
   ├── ☁️ Cloudinary Cloud Asset Storage — Evidence & Document Storage
   │
   └── 🧠 AI Image Analysis Pipeline
           │
           ├── 1. Ultralytics YOLO Computer Vision Layer (yolo26n.pt)
           │      └── Detected objects + bounding boxes + confidences
           │
           ├── 2. Civic Issue Classification Service
           │      └── COCO heuristic clustering / direct custom classes
           │
           └── 3. UN SDG Mapping Engine
                  └── Maps civic issues to UN SDGs with relevance scores
           │
           ▼
✨ AI Suggestions Streamed to Flutter UI
   │
   ├── Citizen Confirms / Changes Suggested SDGs (No user lock-in)
   └── Submit Formal Report
           │
           ▼
🐘 PostgreSQL Database (Alembic Managed)
   └── Preserves BOTH AI predictions & Citizen choices for model evaluation
```

---

## ✨ Key Features

* **📷 Evidence Capture & Instant Preview**: Upload or take photos directly in the grievance form with zero UI delay.
* **🧠 Decoupled 3-Tier AI Pipeline**:
  * **YOLO Computer Vision**: Detects objects with confidence scores (loaded once via FastAPI lifespan).
  * **Civic Issue Classification**: Translates detections into actionable municipal issues without fabricating results.
  * **UN SDG Alignment Engine**: Correlates civic issues with UN Sustainable Development Goals (e.g., Waste $\rightarrow$ SDG 11 & SDG 12).
* **👤 Citizen-Centric Control**: AI predictions are assistive suggestions; citizens retain full freedom to select or change SDGs.
* **🌐 Community Feed & Engagement**: Real-time upvoting, single-repost network sharing, and threaded comments.
* **📡 Multi-Device LAN / Physical Device Support**: Test on real Android smartphones connected to your local development Wi-Fi network.
* **☁️ Pluggable Storage**: Cloudinary cloud-native asset storage with HTTPS delivery and local filesystem fallback.
* **🔒 Enterprise Security**: JWT Bearer token authentication, role-based access control (Citizen, Official, Admin), and file size/MIME validation.

---

## 📂 Repository Structure

```text
MEDAL-APP-main/
│
├── backend/                         # FastAPI Backend
│   ├── alembic/                     # Database migrations
│   ├── app/
│   │   ├── database/                # SQLAlchemy session & Base
│   │   ├── models/                  # DB models (User, Complaint, Repost, Upvote, etc.)
│   │   ├── routers/                 # API Endpoints (Auth, Complaints, ML Analysis)
│   │   ├── schemas/                 # Pydantic validation schemas
│   │   └── services/                # Business logic (YOLO, Civic Issue, SDG, Cloudinary Storage)
│   ├── models/                      # Pretrained & fine-tuned YOLO weights (yolo26n.pt)
│   ├── test_images/                 # Curated test suite images
│   ├── uploads/                     # Local fallback storage directory
│   ├── main.py                      # FastAPI entrypoint with Lifespan & CORS
│   └── requirements.txt             # Backend dependencies
│
├── frontend/medal/                  # Flutter Mobile Application
│   ├── lib/
│   │   ├── config/                  # Centralized LAN IP & API configuration
│   │   ├── core/
│   │   │   ├── models/              # Typed models (ImageAnalysisResult, etc.)
│   │   │   └── services/            # ApiService, MlAnalysisService
│   │   └── modules/citizen/         # Screens (Login, Feed, Report Grievance, etc.)
│   └── pubspec.yaml                 # Flutter dependencies
│
├── docs/                            # Technical Documentation
│   ├── ml/
│   │   └── YOLO_TRAINING.md         # Guide for training custom MEDAL YOLO models
│   ├── api_design.md
│   └── project_flow.md
│
├── docker-compose.yml               # Docker Compose services
├── COMMAND.md                       # Complete terminal command cheat sheet
└── README.md                        # Project documentation (this file)
```

---

## 🛠️ Tech Stack

| Component | Technology | Description |
|:---|:---|:---|
| **Mobile App** | Flutter 3.x / Dart 3.x | Cross-platform citizen mobile app |
| **Backend API** | FastAPI / Python 3.10+ | High-performance asynchronous REST API |
| **Computer Vision** | Ultralytics YOLO | Pretrained base weights + extensible custom civic model |
| **Database** | PostgreSQL 15+ | Relational persistence with SQLAlchemy & Alembic |
| **Object Storage**| Cloudinary | Cloud-native media asset management, HTTPS delivery & secure signed URLs |
| **Authentication**| OAuth2 / JWT (python-jose) | Secure token-based session handling |

---

## 🚀 Getting Started

### 1. Prerequisites
Ensure you have the following installed:
* [Python 3.10+](https://www.python.org/)
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+)
* [PostgreSQL](https://www.postgresql.org/download/)
* [Docker & Docker Compose](https://www.docker.com/) (optional, for local DB/services)
* Git

---

### 2. Environment Configuration

#### Backend Setup (`backend/.env`)
Create `backend/.env` based on `backend/.env.example`:

```env
# Database configuration
DATABASE_URL=postgresql+psycopg://postgres:password@localhost:5432/medal_db

# Security & JWT Auth
SECRET_KEY=your_super_secret_jwt_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Pluggable Storage (cloudinary or local)
STORAGE_TYPE=cloudinary
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# YOLO Configuration
YOLO_MODEL_PATH=models/yolo26n.pt
YOLO_CONFIDENCE_THRESHOLD=0.35
YOLO_IOU_THRESHOLD=0.45
```

#### Flutter Setup (`frontend/medal/lib/config/api_config.dart`)
Set your computer's local Wi-Fi IPv4 address (e.g., `172.16.127.223`):
```dart
const String kPcWifiIp = '172.16.127.223';
```

---

### 3. Running Services

#### Step 1: Configure Cloudinary Credentials
Configure `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` in `backend/.env`.
Verify storage readiness with the health check endpoint: `GET /health`.

#### Step 2: Initialize Database & Run Backend
```powershell
cd backend
.\venv\Scripts\activate

# Apply Alembic Migrations
alembic upgrade head

# Start FastAPI server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
Interactive Swagger docs: `http://localhost:8000/docs`  
Health check: `http://localhost:8000/health`

#### Step 3: Run Flutter Application
```powershell
cd frontend/medal
flutter pub get
flutter run
```

---

## 🎯 Image Analysis & SDG Mapping Endpoints

### Analyze Image Evidence
```http
POST /api/v1/ml/analyze-image
Content-Type: multipart/form-data
Authorization: Bearer <token>
```
* **Request**: Form field `image` (binary file, JPEG/PNG/WEBP $\le$ 10MB).
* **Response**:
```json
{
  "success": true,
  "analysis": {
    "issue": {
      "label": "Improper Waste Disposal",
      "category": "waste_dumping",
      "confidence": 0.94
    },
    "detections": [
      { "class": "bottle", "confidence": 0.91 }
    ],
    "sdgs": [
      { "id": 11, "name": "Sustainable Cities and Communities", "confidence": 0.91 },
      { "id": 12, "name": "Responsible Consumption and Production", "confidence": 0.87 }
    ]
  },
  "message": "Image analyzed successfully"
}
```

---

## 🧪 Testing

Run backend test suites:
```powershell
cd backend
.\venv\Scripts\python.exe test_image_analysis.py
.\venv\Scripts\python.exe test_report_creation.py
```

Run Flutter static analysis:
```powershell
cd frontend/medal
flutter analyze
```

---

## 📖 Additional Documentation

* **[COMMAND.md](COMMAND.md)**: Full terminal cheat sheet for developers and operations.
* **[YOLO Model Training Guide](docs/ml/YOLO_TRAINING.md)**: Instructions for labeling, YAML configuration, and fine-tuning custom MEDAL civic models.

---

## 📄 License
This project is licensed under the terms described in the `LICENSE` file.
