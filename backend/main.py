from fastapi import FastAPI
from db.database import supabase

app = FastAPI()

@app.get("/health")
def health_check():
    return {"status": "online", "project": "Convoy Risk Analyzer"}

@app.get("/")
def default_check():
    return {"message": "Welcome to Convoy Risk Analyzer"}

@app.get("/db-test")
def db_test():
    response = supabase.table("users").select("*").execute()
    return {"connected": True, "data": response.data}
