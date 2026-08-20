// THIS IS A META UI FILE
import { CheckboxInput, type FeatureToggle } from '../base';

export const auto_fix_chat_resize: FeatureToggle = {
  name: 'Auto-fix chat on resize',
  category: 'UI',
  description:
    'Periodically checks for a resized game window and automatically redocks the chat panel ' +
    '(the same thing the "Fix chat" OOC verb does) if BYOND left it the wrong size.',
  component: CheckboxInput,
};
