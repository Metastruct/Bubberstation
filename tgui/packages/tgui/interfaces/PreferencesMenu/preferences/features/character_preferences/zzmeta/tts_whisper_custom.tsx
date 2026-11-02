import { type Feature, FeatureShortTextInput } from '../../base';

export const tts_whisper_custom: Feature<string> = {
  name: 'TTS Whisper Voice Customization',
  description: `
    Used by eSpeak, DECtalk and SAPI4 whisper voices.
    eSpeak: "<voice> [speed=<n>] [pitch=<n>] [amplitude=<n>]".
    Ranges: speed 80-4000 (Sonic kicks in at 450), pitch 0-99, amplitude 0-1000
    (100 default; above 200 clips).
    DECtalk: raw commands, e.g. "[:ra 160]".
    SAPI4: "pitch=<n> speed=<n>", or inline as "[Pit=200]" / "[Spd=300]".
    Leave blank to use the selected preset.
  `,
  component: FeatureShortTextInput,
};
