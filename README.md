# FlowMD local backend

The backend is dependency-free Python and streams HealthKit XML into SQLite.

```bash
python3 backend.py
```

Then open `http://127.0.0.1:8000/import.html`.

API endpoints:

- `GET /api/health`
- `POST /api/import` with the raw XML body and optional `X-Filename` header
- `GET /api/imports`
- `GET /api/metrics?metric=heart_rate&days=30`
- `GET /api/insights`
- `GET /api/patients`

The attached export is intentionally not copied into the repository. Use the import page to select it in the browser; the import page can be connected to the POST endpoint when running the local server.
