// THIS IS A META UI FILE
import type { Feature, FeatureChoicedServerData, FeatureValueProps } from '../base';
import { FeatureDropdownInput } from '../dropdowns';

export const feature_eye_shape: Feature<string> = {
  name: 'Eye Shape',
  description:
    'Requires "Allow Mismatched Parts". Purely cosmetic, no mechanical effect.',
  component: (
    props: FeatureValueProps<string, string, FeatureChoicedServerData>,
  ) => {
    return <FeatureDropdownInput buttons {...props} />;
  },
};
