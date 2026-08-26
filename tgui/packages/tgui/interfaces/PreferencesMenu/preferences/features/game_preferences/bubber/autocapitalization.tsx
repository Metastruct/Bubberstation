import { CheckboxInput, type FeatureToggle } from '../../base';

export const autocapitalization: FeatureToggle = {
  name: 'Autocapitalization',
  category: 'CHAT',
  description:
    "When enabled, standalone lowercase 'i's in your messages will be capitalized.",
  component: CheckboxInput,
};
