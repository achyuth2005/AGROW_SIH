"""
Supabase Client for Chat Storage
=================================
Handles conversation persistence with:
- Session management
- Message CRUD
- History retrieval
"""

import os
import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
import json

# Try to import supabase, fallback to in-memory storage
try:
    from supabase import create_client, Client
    SUPABASE_AVAILABLE = True
except ImportError:
    SUPABASE_AVAILABLE = False
    print("Warning: supabase-py not installed, using in-memory storage")


class SupabaseClient:
    """Client for Supabase chat storage operations."""
    
    def __init__(self):
        self.client: Optional[Client] = None
        self._memory_sessions: Dict[str, Dict] = {}
        self._memory_messages: Dict[str, List[Dict]] = {}
        
        if SUPABASE_AVAILABLE:
            url = os.environ.get("SUPABASE_URL")
            key = os.environ.get("SUPABASE_KEY")
            
            if url and key:
                try:
                    self.client = create_client(url, key)
                    print("Supabase client initialized successfully")
                except Exception as e:
                    print(f"Failed to initialize Supabase: {e}")
                    self.client = None
            else:
                print("SUPABASE_URL or SUPABASE_KEY not set")
    
    def is_configured(self) -> bool:
        """Check if Supabase is properly configured."""
        return self.client is not None
    
    # =========================================================================
    # SESSION OPERATIONS
    # =========================================================================
    def create_session(self, user_id: str, title: str = "New Conversation") -> Dict:
        """Create a new chat session."""
        session_id = str(uuid.uuid4())
        now = datetime.now().isoformat()
        
        session_data = {
            "id": session_id,
            "user_id": user_id,
            "title": title,
            "created_at": now,
            "updated_at": now
        }
        
        if self.client:
            try:
                result = self.client.table("chat_sessions").insert(session_data).execute()
                return result.data[0] if result.data else session_data
            except Exception as e:
                print(f"Supabase create session error: {e}")
                # Fallback to memory
        
        # In-memory fallback
        self._memory_sessions[session_id] = session_data
        self._memory_messages[session_id] = []
        return session_data
    
    def get_session(self, session_id: str) -> Optional[Dict]:
        """Get session details."""
        if self.client:
            try:
                result = self.client.table("chat_sessions").select("*").eq("id", session_id).execute()
                return result.data[0] if result.data else None
            except Exception as e:
                print(f"Supabase get session error: {e}")
        
        return self._memory_sessions.get(session_id)
    
    def get_user_sessions(self, user_id: str) -> List[Dict]:
        """Get all sessions for a user, ordered by most recent."""
        if self.client:
            try:
                result = self.client.table("chat_sessions")\
                    .select("*, chat_messages(count)")\
                    .eq("user_id", user_id)\
                    .order("updated_at", desc=True)\
                    .execute()
                
                sessions = []
                for session in result.data:
                    msg_count = 0
                    if session.get("chat_messages"):
                        msg_count = session["chat_messages"][0].get("count", 0) if session["chat_messages"] else 0
                    sessions.append({
                        "id": session["id"],
                        "title": session["title"],
                        "created_at": session["created_at"],
                        "updated_at": session["updated_at"],
                        "message_count": msg_count
                    })
                return sessions
            except Exception as e:
                print(f"Supabase get sessions error: {e}")
        
        # In-memory fallback
        return [
            {**s, "message_count": len(self._memory_messages.get(s["id"], []))}
            for s in self._memory_sessions.values()
            if s.get("user_id") == user_id
        ]
    
    def update_session_timestamp(self, session_id: str):
        """Update session's updated_at timestamp."""
        now = datetime.now().isoformat()
        
        if self.client:
            try:
                self.client.table("chat_sessions")\
                    .update({"updated_at": now})\
                    .eq("id", session_id)\
                    .execute()
            except Exception as e:
                print(f"Supabase update timestamp error: {e}")
        else:
            if session_id in self._memory_sessions:
                self._memory_sessions[session_id]["updated_at"] = now
    
    def update_session_title(self, session_id: str, title: str):
        """Update session title."""
        if self.client:
            try:
                self.client.table("chat_sessions")\
                    .update({"title": title, "updated_at": datetime.now().isoformat()})\
                    .eq("id", session_id)\
                    .execute()
            except Exception as e:
                print(f"Supabase update title error: {e}")
        else:
            if session_id in self._memory_sessions:
                self._memory_sessions[session_id]["title"] = title
    
    def delete_session(self, session_id: str):
        """Delete session and all its messages."""
        if self.client:
            try:
                # Delete messages first (foreign key constraint)
                self.client.table("chat_messages").delete().eq("session_id", session_id).execute()
                self.client.table("chat_sessions").delete().eq("id", session_id).execute()
            except Exception as e:
                print(f"Supabase delete session error: {e}")
        else:
            self._memory_sessions.pop(session_id, None)
            self._memory_messages.pop(session_id, None)
    
    # =========================================================================
    # MESSAGE OPERATIONS
    # =========================================================================
    def add_message(
        self, 
        session_id: str, 
        role: str, 
        content: str,
        context_used: Optional[List[str]] = None
    ) -> str:
        """Add a message to a session."""
        message_id = str(uuid.uuid4())
        now = datetime.now().isoformat()
        
        message_data = {
            "id": message_id,
            "session_id": session_id,
            "role": role,
            "content": content,
            "context_used": json.dumps(context_used) if context_used else None,
            "created_at": now
        }
        
        if self.client:
            try:
                self.client.table("chat_messages").insert(message_data).execute()
                return message_id
            except Exception as e:
                print(f"Supabase add message error: {e}")
        
        # In-memory fallback
        if session_id not in self._memory_messages:
            self._memory_messages[session_id] = []
        self._memory_messages[session_id].append(message_data)
        return message_id
    
    def get_messages(self, session_id: str, limit: int = 100) -> List[Dict]:
        """Get messages for a session, ordered by creation time."""
        if self.client:
            try:
                result = self.client.table("chat_messages")\
                    .select("*")\
                    .eq("session_id", session_id)\
                    .order("created_at")\
                    .limit(limit)\
                    .execute()
                return result.data if result.data else []
            except Exception as e:
                print(f"Supabase get messages error: {e}")
        
        # In-memory fallback
        messages = self._memory_messages.get(session_id, [])
        return sorted(messages, key=lambda m: m.get("created_at", ""))[:limit]
    
    def delete_message(self, message_id: str):
        """Delete a specific message."""
        if self.client:
            try:
                self.client.table("chat_messages").delete().eq("id", message_id).execute()
            except Exception as e:
                print(f"Supabase delete message error: {e}")
        else:
            for session_id, messages in self._memory_messages.items():
                self._memory_messages[session_id] = [
                    m for m in messages if m.get("id") != message_id
                ]
    
    # =========================================================================
    # FIELD DATA OPERATIONS
    # =========================================================================
    def get_user_fields(self, user_id: str) -> List[Dict]:
        """Get all farmland fields for a user."""
        if not self.client:
            return []
        
        try:
            result = self.client.table("coordinates_quad")\
                .select("id, name, crop_type, area_acres, lat1, lon1, lat2, lon2, lat3, lon3, lat4, lon4")\
                .eq("user_id", user_id)\
                .execute()
            return result.data if result.data else []
        except Exception as e:
            print(f"Supabase get fields error: {e}")
            return []
    
    def get_field_by_id(self, field_id: str) -> Optional[Dict]:
        """Get a specific field by ID."""
        if not self.client:
            return None
        
        try:
            result = self.client.table("coordinates_quad")\
                .select("*")\
                .eq("id", field_id)\
                .single()\
                .execute()
            return result.data
        except Exception as e:
            print(f"Supabase get field error: {e}")
            return None
    
    def get_field_context(self, user_id: str, field_name: Optional[str] = None) -> Dict[str, Any]:
        """
        Get field context data formatted for chatbot.
        
        Returns:
            {
                "field_name": str,
                "crop_type": str,
                "area_acres": float,
                "coordinates": {
                    "center_lat": float,
                    "center_lon": float,
                    "bbox": [lon_min, lat_min, lon_max, lat_max]
                },
                "all_fields": List[{name, crop_type, area}]
            }
        """
        fields = self.get_user_fields(user_id)
        
        if not fields:
            return {
                "field_name": "No fields registered",
                "crop_type": "Unknown",
                "area_acres": 0,
                "coordinates": None,
                "all_fields": []
            }
        
        # Find specific field or use first one
        selected_field = None
        if field_name:
            for f in fields:
                if f.get("name", "").lower() == field_name.lower():
                    selected_field = f
                    break
        
        if not selected_field:
            selected_field = fields[0]
        
        # Calculate center and bounding box
        lats = []
        lons = []
        for i in range(1, 5):
            lat = selected_field.get(f"lat{i}")
            lon = selected_field.get(f"lon{i}")
            if lat is not None and lon is not None:
                lats.append(float(lat))
                lons.append(float(lon))
        
        coordinates = None
        if lats and lons:
            center_lat = sum(lats) / len(lats)
            center_lon = sum(lons) / len(lons)
            coordinates = {
                "center_lat": round(center_lat, 6),
                "center_lon": round(center_lon, 6),
                "bbox": [min(lons), min(lats), max(lons), max(lats)]
            }
        
        return {
            "field_name": selected_field.get("name", "Unnamed Field"),
            "crop_type": selected_field.get("crop_type", "Unknown"),
            "area_acres": selected_field.get("area_acres", 0),
            "coordinates": coordinates,
            "all_fields": [
                {
                    "name": f.get("name"),
                    "crop_type": f.get("crop_type"),
                    "area_acres": f.get("area_acres")
                }
                for f in fields
            ]
        }
    
    def get_user_profile(self, user_id: str) -> Optional[Dict]:
        """Get user profile and questionnaire data."""
        if not self.client:
            return None
        
        try:
            # user_profiles columns: user_id, full_name, email, phone_number, 
            # date_of_birth, address, avatar_url, questionnaire_data, updated_at
            result = self.client.table("user_profiles")\
                .select("questionnaire_data, full_name, address")\
                .eq("user_id", user_id)\
                .execute()
            
            # Return first result if any, otherwise None
            if result.data and len(result.data) > 0:
                return result.data[0]
            return None
        except Exception as e:
            print(f"Supabase get profile error: {e}")
            return None

