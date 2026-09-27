"""OpenAI model catalog."""

from ...capabilities import expand_settings

LLM_MODELS: tuple[str, ...] = (
    "gpt-4o-mini",
    "gpt-4o",
    "gpt-4-turbo",
    "gpt-3.5-turbo",
)

DEFAULT_LLM_MODEL = "gpt-4o-mini"

TTS_VOICES: tuple[str, ...] = (
    "alloy", "ash", "ballad", "coral", "echo", "sage", "shimmer", "verse",
)

DEFAULT_TTS_VOICE = "alloy"

# gpt-4o-transcribe is multilingual (Whisper-class ISO 639-1).
_WHISPER = {
    "en": "en",
    "hi": "hi",
    "bn": "bn",
    "ta": "ta",
    "te": "te",
    "gu": "gu",
    "kn": "kn",
    "ml": "ml",
    "mr": "mr",
    "pa": "pa",
    "as": "as",
    "ur": "ur",
    "ne": "ne",
    "sa": "sa",
    "sd": "sd",
}

_TTS_LANGS = {
    "en": "en",
    "hi": "hi",
}

STT_CAPABILITIES: dict[str, dict] = {
    "gpt-4o-transcribe": {
        "languages": dict(_WHISPER),
        "settings": expand_settings(_WHISPER, {}),
    },
}

# Pipecat OpenAITTSSettings has no language field — voice set is global.
TTS_CAPABILITIES: dict[str, dict] = {
    "gpt-4o-mini-tts": {
        "languages": dict(_TTS_LANGS),
        "settings": expand_settings(
            _TTS_LANGS,
            {
                "voice": {
                    "default": DEFAULT_TTS_VOICE,
                    "options": list(TTS_VOICES),
                    "input_type": "dropdown",
                },
            },
        ),
    },
}
