"""Google Cloud Text-to-Speech adapter."""
from google.cloud import texttospeech
from pathlib import Path

VOICE_PRESETS = {
    "neutral": "ko-KR-Neural2-A",
    "calm": "ko-KR-Neural2-B",
    "bright": "ko-KR-Neural2-C",
}


class GoogleTTS:
    """Google Cloud TTS wrapper."""
    
    def __init__(self):
        self.client = texttospeech.TextToSpeechClient()
    
    def synth(self, text: str, preset: str, out: Path) -> bool:
        """Synthesize text to MP3 file."""
        voice_name = VOICE_PRESETS.get(preset, VOICE_PRESETS["neutral"])
        
        inp = texttospeech.SynthesisInput(text=text)
        
        voice = texttospeech.VoiceSelectionParams(
            language_code="ko-KR",
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
