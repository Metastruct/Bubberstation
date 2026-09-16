import { useBackend } from 'tgui/backend';
import { Button, Stack } from 'tgui-core/components';
import {
  type FeatureChoiced,
  type FeatureChoicedServerData,
  type FeatureNumeric,
  FeatureSliderInput,
  type FeatureValueProps,
} from '../../base';
import { FeatureDropdownInput } from '../../dropdowns';

function featureBlooperDropdownInput(playAction: string) {
  return (props: FeatureValueProps<string, string, FeatureChoicedServerData>) => {
    const { act } = useBackend();

    return (
      <Stack>
        <Stack.Item grow>
          <FeatureDropdownInput {...props} />
        </Stack.Item>
        <Stack.Item>
          <Button
            onClick={() => {
              act(playAction);
            }}
            icon="play"
            width="100%"
            height="100%"
          />
        </Stack.Item>
      </Stack>
    );
  };
}

const FeatureBlooperDropdownInput = featureBlooperDropdownInput('play_blooper');
const FeatureWhisperBlooperDropdownInput = featureBlooperDropdownInput(
  'play_whisper_blooper',
);

export const blooper_choice: FeatureChoiced = {
  name: 'Character Voice',
  component: FeatureBlooperDropdownInput,
};

export const whisper_blooper_choice: FeatureChoiced = {
  name: 'Character Whisper',
  description:
    'The voice used only while whispering. Leave as "Same as normal voice" to whisper in your normal voice.',
  component: FeatureWhisperBlooperDropdownInput,
};

export const blooper_speed: FeatureNumeric = {
  name: 'Character Voice Speed %',
  description: 'Lower number, slower voice. Higher number, faster voice.',
  component: FeatureSliderInput,
};

export const blooper_pitch: FeatureNumeric = {
  name: 'Character Voice Pitch %',
  description: 'Lower number, deeper pitch. Higher number, higher pitch.',
  component: FeatureSliderInput,
};

export const blooper_pitch_range: FeatureNumeric = {
  name: 'Character Voice Range %',
  description:
    'Lower number, less pitch range. Higher number, more pitch range.',
  component: FeatureSliderInput,
};

export const whisper_blooper_speed: FeatureNumeric = {
  name: 'Character Whisper Speed %',
  description:
    'Lower number, slower voice. Higher number, faster voice. Only applies while whispering.',
  component: FeatureSliderInput,
};

export const whisper_blooper_pitch: FeatureNumeric = {
  name: 'Character Whisper Pitch %',
  description:
    'Lower number, deeper pitch. Higher number, higher pitch. Only applies while whispering.',
  component: FeatureSliderInput,
};

export const whisper_blooper_pitch_range: FeatureNumeric = {
  name: 'Character Whisper Range %',
  description:
    'Lower number, less pitch range. Higher number, more pitch range. Only applies while whispering.',
  component: FeatureSliderInput,
};
