import { type Feature, FeatureShortTextInput } from '../../base';

export const tts_custom_voice: Feature<string> = {
  name: 'TTS Voice Customization',
  description: `
    Used by eSpeak and DECtalk voices.
    eSpeak: "<voice> [speed=<n>] [pitch=<n>] [amplitude=<n>]", e.g. "en+m3 speed=180"
    (or inline in chat as "[en+m3 speed=180]").
    DECtalk: raw commands, e.g. "[:ra 220][:dv hs 100]" (also usable inline in chat).
    Leave blank to use the selected preset.
  `,
  component: FeatureShortTextInput,
};
