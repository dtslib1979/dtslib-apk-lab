from google.cloud import texttospeech

VOICE_PRESETS = {
    "neutral": "ko-KR-Neural2-A",
    "calm": "ko-KR-Neural2-B",
    "bright": "ko-KR-Neural2-C"
}

_client = None


def get_client():
    global _client
    if _client is None:
        _client = texttospeech.TextToSpeechClient()
    return _client


def synthesize_text(text: str, preset: str = "neutral") -> bytes:
    client = get_client()

    voice_name = VOICE_PRESETS.get(preset, VOICE_PRESETS["neutral"])

    synthesis_input = texttospeech.SynthesisInput(text=text)

    voice = texttospeech.VoiceSelectionParams(
        language_code="ko-KR",
        name=voice_name
    )

    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3
    )

    response = client.synthesize_speech(
        input=synthesis_input,
        voice=voice,
        audio_config=audio_config
    )

    return response.audio_content
