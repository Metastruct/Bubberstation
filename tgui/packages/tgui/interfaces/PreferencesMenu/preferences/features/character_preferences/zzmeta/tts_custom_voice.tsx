import { type Feature, FeatureShortTextInput } from '../../base';

export const tts_custom_voice: Feature<string> = {
  name: 'TTS eSpeak Customisation',
  description: `
    Only used with eSpeak voices. Format:
    "<voice> [speed=<n>] [pitch=<n>] [amplitude=<n>]",
    e.g. "en+m3 speed=180 pitch=60". Leave blank to use the selected preset.
  `,
  component: FeatureShortTextInput,
};
