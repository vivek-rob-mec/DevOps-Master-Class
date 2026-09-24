from fastapi import FastAPI
app=FastAPI(title="${{ values.name }}")
@app.get("/health")
def health():return {"status":"ok","service":"${{ values.name }}"}
