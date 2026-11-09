# app/services/portal_events.py
"""In-process fan-out of small "something changed" events to open portal
WebSockets, per hospital. Endpoints call `publish` after committing; clients
then refetch what they show. One process only (a single uvicorn worker);
several workers would need a shared broker such as Redis."""
import asyncio
import threading
from collections import defaultdict
from typing import Any, Dict, Optional, Set

EVENT_TYPES = {"referral", "case", "alert", "capacity", "team"}


class PortalHub:
    def __init__(self) -> None:
        self._subs: Dict[str, Set[asyncio.Queue]] = defaultdict(set)
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._lock = threading.Lock()

    def subscribe(self, hospital_id: Any) -> asyncio.Queue:
        self._loop = asyncio.get_running_loop()
        q: asyncio.Queue = asyncio.Queue(maxsize=200)
        with self._lock:
            self._subs[str(hospital_id)].add(q)
        return q

    def unsubscribe(self, hospital_id: Any, q: asyncio.Queue) -> None:
        with self._lock:
            subs = self._subs.get(str(hospital_id))
            if subs is not None:
                subs.discard(q)
                if not subs:
                    self._subs.pop(str(hospital_id), None)

    def listeners(self, hospital_id: Any) -> int:
        with self._lock:
            return len(self._subs.get(str(hospital_id), ()))

    def publish(self, hospital_id: Any, type_: str, id_: Any = None) -> None:
        """Safe to call from sync endpoints (thread pool) and async code."""
        if hospital_id is None or type_ not in EVENT_TYPES:
            return
        with self._lock:
            queues = list(self._subs.get(str(hospital_id), ()))
        loop = self._loop
        if not queues or loop is None or loop.is_closed():
            return
        event = {"type": type_, "id": str(id_) if id_ is not None else None}
        for q in queues:
            loop.call_soon_threadsafe(_offer, q, event)


def _offer(q: asyncio.Queue, event: Dict[str, Any]) -> None:
    try:
        q.put_nowait(event)
    except asyncio.QueueFull:
        pass  # a slow client refetches everything on its next event anyway


hub = PortalHub()
