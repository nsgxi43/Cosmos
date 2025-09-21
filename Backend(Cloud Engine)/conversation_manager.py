# conversation_manager.py
import uuid
import time
from google.cloud import firestore
from google.oauth2 import service_account

credentials = service_account.Credentials.from_service_account_file("response_credentials.json")
db = firestore.Client(credentials=credentials)

class ConversationManager:
    def __init__(self, user_id: str):
        self.user_id = user_id
        # Corrected the path to match your logic: users -> {user_id} -> conversations
        self.convo_ref = db.collection("users").document(user_id).collection("conversations")

    def add_message(self, sender: str, text: str):
        """
        Save a new message to Firestore with guaranteed unique ID.
        sender: "user" or "ai"
        Only stores text and timestamp.
        """
        # Generate guaranteed unique document ID
        unique_id = f"{sender}_{int(time.time() * 1000)}_{uuid.uuid4().hex[:8]}"
        
        data = {
            "sender": sender,
            "text": text,
            "timestamp": firestore.SERVER_TIMESTAMP
        }
        
        # ✅ Use .document().set() instead of .add() for guaranteed uniqueness
        self.convo_ref.document(unique_id).set(data)
        print(f"📝 DEBUG: Saved message with ID: {unique_id}")

    def get_last_messages(self, limit=6):
        """Fetch last N messages (user + AI)"""
        try:
            docs = (
                self.convo_ref.order_by("timestamp", direction=firestore.Query.DESCENDING)
                .limit(limit)
                .stream()
            )
            # Correctly reverses the list to be in chronological order
            messages = [doc.to_dict() for doc in docs][::-1]
            print(f"📖 DEBUG: Retrieved {len(messages)} messages")
            return messages
        except Exception as e:
            print(f"\ DEBUG: Error retrieving messages: {e}")
            return []