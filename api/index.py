from fastapi import FastAPI
from fastapi.responses import PlainTextResponse
from openai import OpenAI
from dotenv import load_dotenv
import os

app = FastAPI()

load_dotenv(override=True)

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL")

@app.get("/api", response_class=PlainTextResponse)
def idea():
  client = OpenAI(
    api_key=OPENROUTER_API_KEY,
    base_url=OPENROUTER_BASE_URL
  )
  prompt = [{"role": "user", "content": "Come up with a new business idea for AI Agents"}]
  response = client.chat.completions.create(model="gpt-5-nano", messages=prompt)
  return response.choices[0].message.content


  