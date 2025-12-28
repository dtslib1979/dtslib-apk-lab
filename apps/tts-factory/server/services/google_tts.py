"""Google Cloud Text-to-Speech adapter."""
from google.cloud import texttospeech
from pathlib import Path

VOICE_PRESETS = {
    "en": {
        "neutral": "en-US-Neural2-D",
        "calm": "en-US-Neural2-A",
        "bright": "en-US-Neural2-F",
    },
    "ja": {
        "neutral": "ja-JP-Neural2-B",
        "calm": "ja-JP-Neural2-C",
        "bright": "ja-JP-Neural2-D",
    },
    "zh": {
        "neutral": "zh-CN-Neural2-A",
        "calm": "zh-CN-Neural2-B",
        "bright": "zh-CN-Neural2-C",
    },
    "es": {
        "neutral": "es-ES-Neural2-A",
        "calm": "es-ES-Neural2-B",
        "bright": "es-ES-Neural2-C",
    },
    "ko": {
        "neutral": "ko-KR-Neural2-A",
        "calm": "ko-KR-Neural2-B",
        "bright": "ko-KR-Neural2-C",
    },
}

LANG_CODES = {
    "en": "en-US",
    "ja": "ja-JP",
    "zh": "zh-CN",
    "es": "es-ES",
    "ko": "ko-KR",
}


class GoogleTTS:
    """Google Cloud TTS wrapper."""

    def __init__(self):
        self.client = texttospeech.TextToSpeechClient()

    def synth(self, text: str, preset: str, language: str, out: Path) -> bool:
        """Synthesize text to MP3 file."""
        lang_presets = VOICE_PRESETS.get(language, VOICE_PRESETS["en"])
        voice_name = lang_presets.get(preset, lang_presets["neutral"])
        lang_code = LANG_CODES.get(language, "en-US")

        inp = texttospeech.SynthesisInput(text=text)

        voice = texttospeech.VoiceSelectionParams(
            language_code=lang_code,
            name=voice_name,
        )

        audio_cfg = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3
        )

        try:
            resp = self.client.synthesize_speech(
                input=inp,
                voice=voice,
                audio_config=audio_cfg,
            )
            out.write_bytes(resp.audio_content)
            return True
        except Exception as e:
            print(f"TTS error: {e}")
            return False
