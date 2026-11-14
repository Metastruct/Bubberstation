import { CheckboxInput, type FeatureToggle } from '../base';

export const extra_arms_toggle: FeatureToggle = {
  name: 'Extra Arms',
  description:
    'Adds a second, functional pair of arms to your chest. Only available to non-moth species, and only with "Allow Mismatched Parts" enabled.',
  component: CheckboxInput,
};
