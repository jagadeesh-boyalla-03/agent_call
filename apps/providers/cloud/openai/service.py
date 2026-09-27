"""Build Pipecat (or adapter) services from this vendor's configs."""

from __future__ import annotations

from ...registry import register_llm, register_stt, register_tts, api_key, llm_settings
from .config import OpenAILLMConfig, OpenAISTTConfig, OpenAITTSConfig


@register_stt
def create_stt(cfg: OpenAISTTConfig):
    from pipecat.services.openai.stt import OpenAISTTService, OpenAISTTSettings

    return OpenAISTTService(
        api_key=api_key(cfg.api_key),
        settings=OpenAISTTSettings(model=cfg.model, language=cfg.language),
    )


@register_tts
def create_tts(cfg: OpenAITTSConfig):
    from pipecat.services.openai.tts import OpenAITTSService, OpenAITTSSettings

    return OpenAITTSService(
        api_key=api_key(cfg.api_key),
        settings=OpenAITTSSettings(model=cfg.model, voice=cfg.voice),
    )


_VALID_OPENAI_MODELS = {
    "gpt-4.1": "gpt-4o",
    "gpt-4.1-mini": "gpt-4o-mini",
    "gpt-4.1-nano": "gpt-4o-mini",
    "gpt-5": "gpt-4o",
    "gpt-5-mini": "gpt-4o-mini",
    "gpt-5-nano": "gpt-4o-mini",
}


@register_llm
def create_llm(cfg: OpenAILLMConfig):
    from pipecat.services.openai.base_llm import OpenAILLMSettings
    from pipecat.services.openai.llm import OpenAILLMService

    settings = llm_settings(cfg)
    model = settings.get("model") or cfg.model
    if model in _VALID_OPENAI_MODELS:
        settings["model"] = _VALID_OPENAI_MODELS[model]

    return OpenAILLMService(
        api_key=api_key(cfg.api_key),
        settings=OpenAILLMSettings(**settings),
    )
