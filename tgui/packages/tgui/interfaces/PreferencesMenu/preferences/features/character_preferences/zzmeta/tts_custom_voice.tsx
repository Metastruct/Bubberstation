import { type Feature, FeatureShortTextInput } from '../../base';

export const tts_custom_voice: Feature<string> = {
  name: 'TTS Voice Customization',
  description: `
    Used by eSpeak, DECtalk and SAPI4 voices.
    eSpeak: "<voice> [speed=<n>] [pitch=<n>] [amplitude=<n>]", e.g. "en+m3 speed=180"
    (or inline in chat as "[en+m3 speed=180]").
    Ranges: speed 80-4000 (Sonic kicks in at 450), pitch 0-99, amplitude 0-1000
    (100 default; above 200 clips).
    DECtalk: raw commands, e.g. "[:ra 220][:dv hs 100]" (also usable inline in chat).
    SAPI4: "pitch=<n> speed=<n>" (clamped to the voice's own range), or inline in
    chat as "[Pit=200]", "[Spd=300]", "[Pau=1000]", "[Vol=150]", "[Rst]".
    Leave blank to use the selected preset.
  `,
  component: FeatureShortTextInput,
};
