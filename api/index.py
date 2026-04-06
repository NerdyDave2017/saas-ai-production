from fastapi import FastAPI  # type: ignore
from fastapi.responses import StreamingResponse  # type: ignore
from openai import OpenAI  # type: ignore
from dotenv import load_dotenv
import os

app = FastAPI()

load_dotenv(override=True)

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY")
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL")

@app.get("/api")
def idea():
  client = OpenAI(
    api_key=OPENROUTER_API_KEY,
    base_url=OPENROUTER_BASE_URL
  )
  prompt = prompt = [{"role": "user", "content": "Reply with a new business idea for AI Agents, formatted with headings, sub-headings and bullet points"}]
  stream = client.chat.completions.create(model="gpt-5-nano", messages=prompt, stream=True)

  def event_stream():
    for chunk in stream:
      text = chunk.choices[0].delta.content
      if text:
          lines = text.split("\n")
          for line in lines:
              yield f"data: {line}\n"
          yield "\n"

  return StreamingResponse(event_stream(), media_type="text/event-stream")


  