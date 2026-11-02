import type { FeatureChoiced } from '../../base';
import { FeatureDropdownInput } from '../../dropdowns';

export const tts_silicon_effect: FeatureChoiced = {
  name: 'Silicon TTS Voice Effect',
  description: `
    The effect applied to borg/AI (silicon) TTS voices.
    Preview it with the robot button next to any TTS voice.
  `,
  component: FeatureDropdownInput,
};
