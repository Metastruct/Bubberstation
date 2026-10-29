import { useBackend } from 'tgui/backend';
import { Button, Stack } from 'tgui-core/components';

import type {
  FeatureChoiced,
  FeatureChoicedServerData,
  FeatureValueProps,
} from '../../base';
import { FeatureDropdownInput } from '../../dropdowns';

function FeatureWhisperVoiceInput(
  props: FeatureValueProps<string, string, FeatureChoicedServerData>,
) {
  const { act } = useBackend();

  return (
    <Stack>
      <Stack.Item grow>
        <FeatureDropdownInput {...props} />
      </Stack.Item>
      <Stack.Item>
        <Button
          onClick={() => {
            act('play_whisper_voice');
          }}
          icon="play"
          width="100%"
          height="100%"
        />
      </Stack.Item>
    </Stack>
  );
}

export const tts_whisper_voice: FeatureChoiced = {
  name: 'TTS Whisper Voice',
  description: `
    The TTS voice used only while whispering.
    Leave as "Same as normal voice" to whisper in your normal TTS voice.
  `,
  component: FeatureWhisperVoiceInput,
};
