# FastAPI backend for Environment Noise

Python implementation of the backend originally written in Go. It exposes the same routes and uses SQLite for data storage.

## Requirements
- Python 3.10+
- Access to the audio files under `backend/data` (default)

## Setup
1. Open a shell at the repo root: `cd backend`.
2. Create a virtualenv (optional but recommended):
   ```bash
   python -m venv .venv
   # Windows
   .venv\Scripts\activate
   # macOS/Linux
   source .venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Configuration
Environment variables (optional overrides):
- `NOISE_BACKEND_PORT` (default `8080`)
- `NOISE_DB_PATH` (default `./data/white_noise.db`)
- `NOISE_DATA_DIR` (default `./data`)

## Run
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port 8080
```
The API will seed the SQLite database on first start if empty.

## Docker Deployment
1. Build the image:
   ```bash
   docker build -t noise-backend .
   ```
2. Run the container:
   ```bash
   docker run -p 8080:8080 -v ${PWD}/data:/app/data noise-backend
   ```
   *Note: Using a volume mount for `/app/data` ensures your database and audio files persist.*

## API surface (matches Go backend)
- `GET /data/{filepath}` – serve audio files (mp3/wav/ogg)
- `GET /api/v1/audio` – list available audio files
- `GET /api/v1/scenes` – list scenes with metadata
- `GET /api/v1/scenes/{id}` – scene detail with tracks
- `GET /api/v1/presets` – list presets with track volumes
- `POST /api/v1/listening-session` – accept session payload (acknowledges only)
