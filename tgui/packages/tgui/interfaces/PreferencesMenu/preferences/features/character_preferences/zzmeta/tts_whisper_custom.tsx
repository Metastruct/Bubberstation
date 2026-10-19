import { type Feature, FeatureShortTextInput } from '../../base';

export const tts_whisper_custom: Feature<string> = {
  name: 'TTS Whisper Voice Customization',
  description: `
    Used by eSpeak and DECtalk whisper voices.
    eSpeak: "<voice> [speed=<n>] [pitch=<n>] [amplitude=<n>]".
    DECtalk: raw commands, e.g. "[:ra 160]".
    Leave blank to use the selected preset.
  `,
  component: FeatureShortTextInput,
};
