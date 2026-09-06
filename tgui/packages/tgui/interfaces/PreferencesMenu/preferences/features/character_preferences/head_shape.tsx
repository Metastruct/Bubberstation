// THIS IS A META UI FILE
import {
  CheckboxInput,
  type Feature,
  type FeatureChoicedServerData,
  type FeatureToggle,
  type FeatureValueProps,
} from '../base';
import { FeatureDropdownInput } from '../dropdowns';

export const head_shape_toggle: FeatureToggle = {
  name: 'Head Shape',
  description: 'Requires "Allow Mismatched Parts".',
  component: CheckboxInput,
};

export const feature_head_shape: Feature<string> = {
  name: 'Head Shape Selection',
  description:
    'Purely cosmetic reskin. "Headless" hides the head entirely. Existing colors and hair still apply normally.',
  component: (
    props: FeatureValueProps<string, string, FeatureChoicedServerData>,
  ) => {
    return <FeatureDropdownInput buttons {...props} />;
  },
};
