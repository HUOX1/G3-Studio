from __future__ import annotations

import asyncio
import hmac
import json
import logging
from collections.abc import Awaitable, Callable

from websockets.asyncio.server import ServerConnection, serve

from .protocol import (
    PROTOCOL_VERSION,
    ProtocolError,
    event_message,
    parse_request,
    response_message,
)


HOST = "127.0.0.1"
PORT = 8765

logger = logging.getLogger("g3.websocket")


class TerminalWebSocketServer:
    def __init__(
        self,
        command_handler: Callable[[str, dict], Awaitable[object]],
        *,
        host: str = HOST,
        port: int = PORT,
        token: str,
    ) -> None:
        if host != HOST:
            raise ValueError("v0.6 backend must bind to 127.0.0.1")
        if not isinstance(token, str) or len(token) < 32:
            raise ValueError("a per-launch authentication token is required")
        self._token = token
        self._command_handler = command_handler
        self.host = host
        self.port = int(port)
        self._server = None
        self._clients: set[ServerConnection] = set()

    @property
    def bound_port(self) -> int:
        if self._server is None or not self._server.sockets:
            return self.port
        return int(self._server.sockets[0].getsockname()[1])

    async def start(self) -> None:
        self._server = await serve(
            self._handle_connection, self.host, self.port, origins=[None],
            max_size=8 * 1024 * 1024,
        )

    async def close(self) -> None:
        if self._server is not None:
            self._server.close()
            await self._server.wait_closed()
            self._server = None
        self._clients.clear()

    async def broadcast(self, event_type: str, payload: dict[str, object]) -> None:
        if not self._clients:
            return
        message = json.dumps(event_message(event_type, payload))
        stale: list[ServerConnection] = []
        for client in tuple(self._clients):
            try:
                await client.send(message)
            except Exception:
                stale.append(client)
        for client in stale:
            self._clients.discard(client)

    async def _handle_connection(self, websocket: ServerConnection) -> None:
        # Browser WebSockets include an Origin header, rejected by serve(origins=[None]).
        # Loopback alone is not authentication. Only a valid, per-launch token
        # grants access to business commands and event broadcasts.
        try:
            try:
                raw = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                request = parse_request(json.loads(raw))
            except (asyncio.TimeoutError, json.JSONDecodeError, ProtocolError, ValueError):
                await websocket.close(code=1008, reason="invalid handshake")
                return

            if request.type != "hello":
                await websocket.send(json.dumps(response_message(
                    request.id,
                    error={"code": "handshake_required", "message": "hello required"},
                )))
                await websocket.close(code=1008, reason="handshake required")
                return

            supplied = request.payload.get("token")
            if (request.payload.get("protocol") != PROTOCOL_VERSION
                    or not isinstance(supplied, str)
                    or not hmac.compare_digest(supplied, self._token)):
                await websocket.send(json.dumps(response_message(
                    request.id,
                    error={"code": "authentication_failed", "message": "handshake rejected"},
                )))
                await websocket.close(code=1008, reason="handshake rejected")
                return

            await websocket.send(json.dumps(response_message(
                request.id, data={"protocol": PROTOCOL_VERSION},
            )))
            self._clients.add(websocket)
            async for raw in websocket:
                request_id = ""
                request_type = ""
                request_payload: dict = {}
                try:
                    request = parse_request(json.loads(raw))
                    request_id = request.id
                    request_type = request.type
                    request_payload = request.payload
                    if request_type == "hello":
                        raise ProtocolError("handshake already completed")
                    result = await self._command_handler(request.type, request.payload)
                    await websocket.send(json.dumps(response_message(request.id, data=result)))
                except (json.JSONDecodeError, ProtocolError, ValueError) as exc:
                    logger.warning("Bad backend request: type=%s id=%s error=%s",
                                   request_type, request_id, exc)
                    await websocket.send(json.dumps(response_message(
                        request_id or "invalid",
                        error={"code": "bad_request", "message": str(exc)},
                    )))
                except (KeyError, FileNotFoundError) as exc:
                    logger.error("Backend command failed: type=%s id=%s error=%s",
                                 request_type, request_id, exc, exc_info=True)
                    await websocket.send(json.dumps(response_message(
                        request_id or "invalid",
                        error={"code": "not_found", "message": str(exc)},
                    )))
                except Exception:
                    logger.exception("Backend command failed: type=%s id=%s", request_type, request_id)
                    await websocket.send(json.dumps(response_message(
                        request_id or "invalid",
                        error={"code": "internal_error", "message": "command failed"},
                    )))
        finally:
            self._clients.discard(websocket)
