"""Protobuf serializer tuned for the JS WebSocketTransport browser client."""

from __future__ import annotations

from pipecat.frames.frames import (
    Frame,
    OutputAudioRawFrame,
    OutputTransportMessageFrame,
    OutputTransportMessageUrgentFrame,
)
from pipecat.serializers.protobuf import MessageFrame, ProtobufFrameSerializer


class BrowserProtobufFrameSerializer(ProtobufFrameSerializer):
    """Only serialize frames the browser client can deserialize.

    ``@pipecat-ai/websocket-transport`` accepts ``audio`` and ``message``
    only; ``text`` / ``transcription`` / ``interruption`` raise
    ``Unknown frame kind`` in the browser and spam the Next.js overlay.
    RTVI events still ride on ``MessageFrame``.
    """

    SERIALIZABLE_TYPES = {
        OutputAudioRawFrame: "audio",
        MessageFrame: "message",
    }
    SERIALIZABLE_FIELDS = {v: k for k, v in SERIALIZABLE_TYPES.items()}

    async def serialize(self, frame: Frame) -> str | bytes | None:
        # Drop text/transcription/interruption quietly (parent would warn).
        if isinstance(
            frame,
            (OutputTransportMessageFrame, OutputTransportMessageUrgentFrame),
        ):
            return await super().serialize(frame)
        if type(frame) not in self.SERIALIZABLE_TYPES:
            return None
        return await super().serialize(frame)
