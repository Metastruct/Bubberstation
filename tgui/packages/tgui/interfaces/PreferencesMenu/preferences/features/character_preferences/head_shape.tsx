// THIS IS A META UI FILE
import type { Feature, FeatureChoicedServerData, FeatureValueProps } from '../base';
import { FeatureDropdownInput } from '../dropdowns';

export const feature_head_shape: Feature<string> = {
  name: 'Head Shape',
  description:
    'Requires "Allow Mismatched Parts". Purely cosmetic reskin, hair and facial hair still render normally.',
  component: (
    props: FeatureValueProps<string, string, FeatureChoicedServerData>,
  ) => {
    return <FeatureDropdownInput buttons {...props} />;
  },
};
