import asyncio
import base64
import json
import os
import time
import uuid
from collections import defaultdict
import subprocess
from datetime import datetime

import cv2
import numpy as np
import requests
from fer import FER
from funasr import AutoModel
from google.cloud import speech
from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import soundfile as sf
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore import Query

from conversation_manager import ConversationManager

# --- Configuration ---
RATE = 48000
SERVICE_ACCOUNT_FILE = "response_credentials.json"
FIREBASE_CREDENTIALS_FILE = "response_credentials.json" 

SCOPES = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/generative-language"
]
GEMINI_FLASH_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
GEMINI_PRO_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent"

# Perspective API
PERSPECTIVE_API_KEY = "<YOUR-API-KEY>"
PERSPECTIVE_URL = "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze"

# Dynamic user configuration
USER_COLLECTION = "users"

app = FastAPI()

# Enhanced CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with your specific domains
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"]
)

# Add explicit OPTIONS handler for preflight requests
@app.options("/{full_path:path}")
async def options_handler(full_path: str):
    """Handle preflight OPTIONS requests explicitly"""
    return Response(
        status_code=200,
        headers={
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Max-Age": "86400",
        }
    )

# Also add this middleware to ensure CORS headers on all responses
@app.middleware("http")
async def add_cors_headers(request, call_next):
    response = await call_next(request)
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "*"
    return response

# Pydantic models
class JournalRequest(BaseModel):
    title: str
    content: str
    visibility: str
    user_id: str

# --- Model and Services Initialization ---
print("Initializing server and loading models...")
try:
    audio_model = AutoModel(model="iic/emotion2vec_plus_seed", hub="hf", device="cpu", disable_pbar=True)
    video_detector = FER(mtcnn=True)
    speech_client = speech.SpeechClient.from_service_account_file(SERVICE_ACCOUNT_FILE)
    gcp_credentials = service_account.Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE, scopes=SCOPES)
    authed_session = AuthorizedSession(gcp_credentials)
    
    if not firebase_admin._apps:
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_FILE)
        firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("Firebase connected.")
except Exception as e:
    print(f"Critical error during initialization: {e}")
    exit()
print("Server ready.")

# --- Helper Functions ---

def ensure_user_exists(user_id: str):
    """Ensure a user document exists - only store user_id and creation timestamp"""
    try:
        user_ref = db.collection(USER_COLLECTION).document(user_id)
        user_doc = user_ref.get()
        
        if not user_doc.exists:
            user_ref.set({
                "created_at": datetime.utcnow(),
                "user_id": user_id
            })
            print(f"Created user document for {user_id}")
    except Exception as e:
        print(f"Error ensuring user exists: {e}")

async def convert_webm_to_pcm(webm_data: bytes) -> bytes:
    """Converts WEBM audio data to raw PCM format using FFmpeg."""
    input_filename = f"/tmp/{uuid.uuid4()}.webm"
    output_filename = f"/tmp/{uuid.uuid4()}.raw"

    with open(input_filename, "wb") as f:
        f.write(webm_data)

    try:
        command = [
            "ffmpeg",
            "-i", input_filename,
            "-ar", str(RATE),
            "-ac", "1",
            "-f", "s16le",
            output_filename
        ]
        subprocess.run(command, check=True, capture_output=True)

        with open(output_filename, "rb") as f:
            pcm_data = f.read()
        return pcm_data
    except subprocess.CalledProcessError as e:
        print(f"FFmpeg conversion failed: {e.stderr.decode()}")
        return b""
    finally:
        if os.path.exists(input_filename):
            os.remove(input_filename)
        if os.path.exists(output_filename):
            os.remove(output_filename)

async def process_video_frame_emotion(frame_b64: str) -> dict:
    """Process a single video frame for emotion detection."""
    try:
        frame_bytes = base64.b64decode(frame_b64)
        nparr = np.frombuffer(frame_bytes, np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if frame is None:
            return {}
        
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        emotions = video_detector.detect_emotions(frame_rgb)
        
        if not emotions:
            return {}
            
        return emotions[0].get("emotions", {})
        
    except Exception as e:
        print(f"Error processing video frame: {e}")
        return {}

def aggregate_video_emotions(emotion_list):
    """Aggregate multiple emotion dictionaries into a single dominant emotion."""
    if not emotion_list:
        return None, {}
    
    all_scores = defaultdict(float)
    count = 0
    
    for emotions in emotion_list:
        if emotions:
            for emotion, score in emotions.items():
                all_scores[emotion] += score
            count += 1
    
    if count == 0:
        return None, {}
    
    avg_scores = {emotion: score / count for emotion, score in all_scores.items()}
    dominant_emotion = max(avg_scores, key=avg_scores.get)
    
    return dominant_emotion, avg_scores

async def run_stt(pcm_data: bytes) -> list:
    """Runs Speech-to-Text on raw PCM audio data."""
    if not pcm_data:
        return [""]
        
    audio = speech.RecognitionAudio(content=pcm_data)
    config = speech.RecognitionConfig(
        encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
        sample_rate_hertz=RATE,
        language_code="en-US"
    )
    response = await asyncio.to_thread(speech_client.recognize, config=config, audio=audio)
    return [r.alternatives[0].transcript for r in response.results]

async def run_audio_emotion(pcm_data: bytes) -> dict:
    """Runs audio emotion analysis on raw PCM audio data."""
    if not pcm_data:
        return {}

    temp_file = f"/tmp/{uuid.uuid4()}.wav"
    try:
        audio_float32 = np.frombuffer(pcm_data, dtype=np.int16).astype(np.float32) / 32768.0
        await asyncio.to_thread(sf.write, temp_file, audio_float32, RATE)
        
        rec_result = await asyncio.to_thread(audio_model.generate, input=temp_file)
        if rec_result and 'scores' in rec_result[0] and 'labels' in rec_result[0]:
            return dict(zip(rec_result[0]['labels'], rec_result[0]['scores']))
    finally:
        if os.path.exists(temp_file):
            os.remove(temp_file)
    return {}

def query_gemini_text(input_json: dict, conversation_history: str) -> str:
    audio_emotion = input_json.get("audio_emotion", "")
    video_emotion = input_json.get("video_emotion", "")
    if audio_emotion: 
        audio_emotion = audio_emotion.split('/')[-1].strip()
    if video_emotion: 
        video_emotion = video_emotion.split('/')[-1].strip()
    
    history_context = ""
    if conversation_history:
        history_context = f"""
RECENT CONVERSATION CONTEXT:
{conversation_history}

"""

    prompt_text = f"""You are Polaris, an empathetic conversational agent and wellness companion. You blend the qualities of a therapist and close friend.

{history_context}CORE GUIDELINES:
- Always prioritize the emotion expressed in the text
- Be warm, understanding, and naturally conversational
- Intelligently decide when conversation history is relevant to the current question - use it when it helps provide better context, ignore it when it doesn't relate to the current input
- If video and audio emotions differ from text, blend them subtly without mentioning the mismatch
- Adjust response length proportionally to user input - keep it short for basic questions and expand only when the topic truly demands more comprehensive coverage
- Paraphrase rather than repeat the user's exact words
- No emojis

CURRENT INPUT ANALYSIS:
- Text: "{input_json.get('text_input', '')}"
- Video emotion detected: {video_emotion or 'none'}  
- Audio emotion detected: {audio_emotion or 'none'}

Respond naturally as Polaris, keeping your response conversational and supportive."""

    payload = {
        "contents": [{"parts": [{"text": prompt_text}]}],
        "generationConfig": {"temperature": 0.8, "maxOutputTokens": 4000},
    }
    
    models_to_try = [
        {"name": "Gemini 1.5 Flash", "url": GEMINI_FLASH_URL},
        {"name": "Gemini 1.5 Pro", "url": GEMINI_PRO_URL}
    ]
    max_retries = 3
    base_delay = 1
    
    for model in models_to_try:
        for i in range(max_retries):
            try:
                resp = authed_session.post(model['url'], json=payload, timeout=120)
                if resp.status_code >= 500:
                    time.sleep(base_delay * (2**i))
                    continue
                resp.raise_for_status()
                resj = resp.json()
                return resj["candidates"][0]["content"]["parts"][0]["text"].strip()
            except Exception as e:
                if i < max_retries - 1:
                    time.sleep(base_delay * (2**i))
    
    return "I'm sorry, I'm facing some technical difficulties connecting to my brain right now. Please try again in a moment."

def query_google_tts(text: str) -> bytes:
    if not text.strip(): 
        return b""
    try:
        from google.cloud import texttospeech
        client = texttospeech.TextToSpeechClient.from_service_account_file(SERVICE_ACCOUNT_FILE)
        synthesis_input = texttospeech.SynthesisInput(text=text)
        voice = texttospeech.VoiceSelectionParams(
            language_code="en-US", name="en-US-Chirp3-HD-Algieba"
        )
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.LINEAR16,
            sample_rate_hertz=16000, 
            speaking_rate=0.9
        )
        response = client.synthesize_speech(
            input=synthesis_input, voice=voice, audio_config=audio_config
        )
        return response.audio_content
    except Exception as e:
        print(f"Google TTS error: {e}")
        return b""

# Journal helper functions
def get_latest_conversation(user_id: str):
    """Fetch latest user conversations from Firestore using ConversationManager."""
    try:
        conv_manager = ConversationManager(user_id)
        messages = conv_manager.get_last_messages(limit=10)
        
        if not messages:
            return None
        
        # Extract user messages for context
        user_texts = []
        for msg in messages:
            if msg.get("sender") == "user" and msg.get("text", "").strip():
                user_texts.append(msg.get("text", ""))
        
        # Also include AI responses for better context
        ai_responses = []
        for msg in messages:
            if msg.get("sender") == "ai" and msg.get("text", "").strip():
                ai_responses.append(msg.get("text", ""))
        
        conversation_context = []
        if user_texts:
            conversation_context.append("Recent topics discussed: " + " | ".join(user_texts[-3:]))
        if ai_responses:
            conversation_context.append("AI responses focused on: " + " | ".join(ai_responses[-2:]))
        
        return " ".join(conversation_context) if conversation_context else None
    
    except Exception as e:
        print(f"Conversation fetch failed: {e}")
        return None

def save_journal(title: str, content: str, visibility: str, user_id: str):
    """Save journal entry under users → user_id → journals → [doc]."""
    try:
        # Ensure user exists before saving journal
        ensure_user_exists(user_id)
        
        journals_ref = db.collection(USER_COLLECTION).document(user_id).collection("journals")
        doc_ref = journals_ref.document()
        doc_ref.set(
            {
                "title": title,
                "content": content,
                "visibility": visibility,
                "timestamp": datetime.utcnow(),
            }
        )
        print(f"Journal saved for user {user_id}")
    except Exception as e:
        print(f"Failed to save journal: {e}")

def check_toxicity(text: str) -> float:
    """Check toxicity using Perspective API."""
    try:
        payload = {
            "comment": {"text": text},
            "languages": ["en"],
            "requestedAttributes": {"TOXICITY": {}}
        }
        resp = requests.post(f"{PERSPECTIVE_URL}?key={PERSPECTIVE_API_KEY}", json=payload)
        resp.raise_for_status()
        score = resp.json()["attributeScores"]["TOXICITY"]["summaryScore"]["value"]
        return score
    except Exception as e:
        print(f"Perspective API call failed: {e}")
        return 0.0

def generate_one_suggestion(convo_context: str) -> str:
    """Generate a suggestion using Gemini API."""
    if not authed_session:
        return "Take a moment to reflect on what's bringing you joy today."

    # Create prompt based on whether we have conversation context
    if convo_context:
        prompt = f"""Context: {convo_context}

Write a journal prompt based on the above context. Start with "Write about" or "Reflect on". One sentence only."""
    else:
        prompt = "Write a therapeutic journal prompt. Start with 'Write about' or 'Reflect on'. One sentence only."

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.3, 
            "maxOutputTokens": 50,
            "stopSequences": ["\n", ".", "!", "?"]
        }
    }
    try:
        resp = authed_session.post(GEMINI_FLASH_URL, json=payload)
        resp.raise_for_status()
        result = resp.json()
        content = result.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "Take a moment to reflect on what's bringing you joy today.")
        return content.strip()
    except Exception as e:
        print(f"Gemini API call failed: {e}")
        return "Take a moment to reflect on what's bringing you joy today."

# --- ROUTES ---

# AI WebSocket endpoint
@app.websocket("/process")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("Client connected for a single turn.")
    video_frames = []
    audio_data = None
    user_id = None
    conv_manager = None
    
    try:
        while True:
            message = json.loads(await websocket.receive_text())
            msg_type = message.get("type")
            
            if msg_type == "init":
                user_id = message.get("user_id")
                if not user_id:
                    raise ValueError("User ID is required")
                
                # Ensure user exists when they connect
                ensure_user_exists(user_id)
                conv_manager = ConversationManager(user_id)
                print(f"User {user_id} connected")
                continue
            elif msg_type == "video":
                video_frames.append(message['data'])
            elif msg_type == "audio_file":
                audio_data = base64.b64decode(message['data'])
                break

        if not conv_manager or not audio_data or not user_id:
            raise ValueError("Required data not received.")

        await websocket.send_text(json.dumps({"type": "status", "message": "transcribing"}))

        pcm_audio_data = await convert_webm_to_pcm(audio_data)

        video_emotion_tasks = [
            asyncio.create_task(process_video_frame_emotion(frame_b64))
            for frame_b64 in video_frames
        ]
        
        stt_task = asyncio.create_task(run_stt(pcm_audio_data))
        audio_emotion_task = asyncio.create_task(run_audio_emotion(pcm_audio_data))

        video_emotion_results = await asyncio.gather(*video_emotion_tasks)
        transcripts, audio_emotion_scores = await asyncio.gather(stt_task, audio_emotion_task)

        valid_emotions = [emotions for emotions in video_emotion_results if emotions]
        
        if valid_emotions:
            video_dominant_emotion, video_emotion_scores = aggregate_video_emotions(valid_emotions)
        else:
            video_dominant_emotion = None

        transcription = transcripts[0] if transcripts else ""
        await websocket.send_text(json.dumps({"type": "interim_transcript", "text": transcription}))
        await websocket.send_text(json.dumps({"type": "status", "message": "thinking"}))

        audio_dominant_emotion = max(audio_emotion_scores, key=audio_emotion_scores.get, default=None)

        last_msgs = await asyncio.to_thread(conv_manager.get_last_messages, limit=8)
        conversation_history = "\n".join([f"{m['sender'].upper()}: {m['text']}" for m in last_msgs]) if last_msgs else ""

        final_input = {
            "text_input": transcription,
            "audio_emotion": audio_dominant_emotion.split('/')[-1].strip() if audio_dominant_emotion else None,
            "video_emotion": video_dominant_emotion
        }
        
        print(f"User {user_id} - video emotion: {video_dominant_emotion}")
        print(f"User {user_id} - audio emotion: {audio_dominant_emotion.split('/')[-1].strip() if audio_dominant_emotion else None}")
        response_text = await asyncio.to_thread(query_gemini_text, final_input, conversation_history)
        
        await asyncio.to_thread(conv_manager.add_message, "user", transcription)
        await asyncio.to_thread(conv_manager.add_message, "ai", response_text)

        response_audio_bytes = await asyncio.to_thread(query_google_tts, response_text)

        response_message = {
            "type": "final_response",
            "text": response_text,
            "data": base64.b64encode(response_audio_bytes).decode('utf-8')
        }
        await websocket.send_text(json.dumps(response_message))
        print(f"Response sent to user {user_id}. Turn complete.")

    except WebSocketDisconnect:
        print("Client disconnected prematurely.")
    except Exception as e:
        print(f"An error occurred during the turn: {e}")
    finally:
        print("Closing connection.")

# Journal endpoints
@app.get("/suggestion/{user_id}")
def get_suggestion(user_id: str):
    convo_context = get_latest_conversation(user_id)
    suggestion = generate_one_suggestion(convo_context)
    return {"suggestion": suggestion}

@app.post("/journal")
def post_journal(req: JournalRequest):
    final_visibility = req.visibility

    if final_visibility == "public":
        toxicity = check_toxicity(req.content)
        if toxicity > 0.7:
            final_visibility = "private"

    save_journal(req.title, req.content, final_visibility, req.user_id)
    return {"status": "ok", "final_visibility": final_visibility}

# Community endpoints
@app.get("/journals/{user_id}")
def get_journals(user_id: str):
    try:
        journals_ref = (
            db.collection("users")
              .document(user_id)
              .collection("journals")
              .order_by("timestamp", direction=Query.DESCENDING)
        )
        docs = journals_ref.stream()

        journals = []
        for doc in docs:
            data = doc.to_dict()
            if "timestamp" in data:
                data["timestamp"] = data["timestamp"].isoformat()
            journals.append(data)

        return {"success": True, "journals": journals}
    except Exception as e:
        print(f"Error fetching journals for user {user_id}: {e}")
        return {"success": False, "error": str(e)}, 500

@app.get("/public_journals")
def get_public_journals():
    try:
        public_journals_ref = (
            db.collection_group("journals")
              .where("visibility", "==", "public")
              .order_by("timestamp", direction=Query.DESCENDING)
        )
        docs = public_journals_ref.stream()

        public_journals = []
        for doc in docs:
            journal_data = doc.to_dict()
            journal_data["id"] = doc.id

            # Get user_id from the document path
            user_id = doc.reference.parent.parent.id
            journal_data["user_id"] = user_id
            

            if "timestamp" in journal_data:
                journal_data["timestamp"] = journal_data["timestamp"].isoformat()

            public_journals.append(journal_data)

        print(f"📱 Total public journals found: {len(public_journals)}")
        
        # Log the first journal for debugging
        if public_journals:
            first_journal = public_journals[0]
            print(f" First journal sample: {first_journal}")
            
        return {"success": True, "journals": public_journals}
        
    except Exception as e:
        print(f"❌ Error fetching public journals: {e}")
        import traceback
        traceback.print_exc()
        return {"success": False, "error": str(e)}, 500
        
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)