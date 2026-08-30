// THIS IS A META UI FILE
import {
  CheckboxInput,
  type Feature,
  type FeatureChoicedServerData,
  type FeatureToggle,
  type FeatureValueProps,
} from '../base';
import { FeatureDropdownInput } from '../dropdowns';

export const eye_shape_toggle: FeatureToggle = {
  name: 'Eye Shape',
  description: 'Requires "Allow Mismatched Parts".',
  component: CheckboxInput,
};

export const feature_eye_shape: Feature<string> = {
  name: 'Eye Shape Selection',
  description: 'Purely cosmetic, no mechanical effect.',
  component: (
    props: FeatureValueProps<string, string, FeatureChoicedServerData>,
  ) => {
    return <FeatureDropdownInput buttons {...props} />;
  },
};
